!> \file
! WABBIT
!> \name block_to_blocks.f90
!> \version 0.5
!> \author sm
!
!> \brief postprocessing routine that generates a WABBIT-readable .h5 file (a field composed in blocks) 
!! from a .h5 file where all data is stored in one block
!
! = log ======================================================================================
!> \date  07/03/18 - create hashcode: commit 
!-----------------------------------------------------------------------------------------------------
!
subroutine block_to_blocks(help, params)
    use module_precision
    use module_mesh
    use module_params
    use module_IO
    use module_initialization, only: allocate_grid, create_equidistant_base_mesh
    use mpi

    implicit none

    !> help flag
    logical, intent(in)                :: help
    !> parameter struct
    type (type_params), intent(inout)  :: params
    character(len=80)      :: file_in
    character(len=80)      :: file_out
    real(kind=rk)          :: time
    integer(kind=ik)       :: iteration

    integer(kind=ik), allocatable     :: lgt_block(:, :)
    real(kind=rk), allocatable        :: hvy_block(:, :, :, :, :), hvy_work(:, :, :, :, :)
    integer(kind=ik), allocatable     :: hvy_neighbor(:,:)
    integer(kind=ik), allocatable     :: lgt_active(:), hvy_active(:)
    integer(kind=tsize), allocatable  :: lgt_sortednumlist(:,:)
    integer(kind=ik), allocatable     :: int_send_buffer(:,:), int_receive_buffer(:,:)
    real(kind=rk), allocatable        :: real_send_buffer(:,:), real_receive_buffer(:,:)
    integer(kind=ik)                  :: hvy_n, lgt_n,level, Bs_tmp, Bs, max_level
    real(kind=rk), dimension(3)       :: domain
    character(len=3)                  :: Bs_read, level_read
    integer(kind=ik), dimension(3)    :: nxyz

!-----------------------------------------------------------------------------------------------------
    level = 0
    params%number_data_fields  = 1
    Bs_tmp = 0
!----------------------------------------------
    if (help .eqv. .true.) then
        if (params%rank==0) then
            write(*,*) "postprocessing subroutine to ................ command line:"
            write(*,*) "mpi_command -n number_procs ./wabbit-post 2D --block_to_blocks source.h5 target.h5 target_blocksize max_level"
        end if
    else
        ! get values from command line (filename and desired blocksize)
        call get_command_argument(3, file_in)
        call check_file_exists(trim(file_in))
        call get_command_argument(4, file_out)
        call get_command_argument(5, Bs_read)
        read(Bs_read,*) Bs
        if (mod(Bs,2)==0) call abort(7844, "ERROR: For WABBIT, we need an odd blocksize!")
        call get_command_argument(6, level_read)
        read(level_read,*) max_level

        ! read attributes such as number of discretisation points, time, domain size
        call get_attributes_flusi(file_in, nxyz, time, domain)
        if (.not. params%threeD_case .and. nxyz(1)/=1) call &
            abort(8714, "ERROR: saved datafield is 3D, WABBIT expects 2D")

        if (nxyz(2)/=nxyz(3)) call abort(8724, "ERROR: nx and ny differ. This is not possible for WABBIT")

        if (mod(nxyz(2),2)/=0) call abort(8324, "ERROR: nx and ny need to be even!")

        do while (level<max_level)
            Bs_tmp = nxyz(2)/2 + 1
            level = level + 1
            if (Bs_tmp==Bs) exit
        end do

        if (Bs_tmp/=Bs) call abort(2948, "ERROR: I'm afraid your saved blocksize does not match for WABBIT or your input max_level is too small")

        params%max_treelevel=level
        params%Lx = domain(2)
        params%Ly = domain(3)
        params%number_block_nodes = Bs
        params%number_ghost_nodes = 0_ik
        if (params%threeD_case) then
            lgt_n = 8_ik**params%max_treelevel
            params%Lz = domain(1)
        else
            lgt_n = 4_ik**params%max_treelevel
        end if
        params%number_blocks = lgt_n/params%number_procs + mod(lgt_n,params%number_procs)
        call allocate_grid( params, lgt_block, hvy_block, hvy_work, hvy_neighbor,&
            lgt_active, hvy_active, lgt_sortednumlist, int_send_buffer, &
            int_receive_buffer, real_send_buffer, real_receive_buffer )
        ! create lists of active blocks (light and heavy data) after load balancing (have changed)
        call create_active_and_sorted_lists( params, lgt_block, lgt_active, lgt_n,&
            hvy_active, hvy_n, lgt_sortednumlist, .true. )

        call create_equidistant_base_mesh( params, lgt_block, hvy_block, hvy_neighbor,&
            lgt_active, lgt_n, lgt_sortednumlist, hvy_active, hvy_n, &
            params%max_treelevel, .true.)
        call read_field_flusi(file_in, hvy_block, lgt_block, hvy_n, hvy_active, params)

        ! do k=1, hvy_n
        !     call hvy_id_to_lgt_id(lgt_id, hvy_active(k), params%rank, params%number_blocks)
        !     call get_block_spacing_origin( params, lgt_id, lgt_block, x0, dx ))
        !     hvy_block(1:Bs-1,1:Bs-1,1,1,hvy_active(k)) = field_in(floor((x0(1)+((1:Bs-1)-1)*dx(1))/dx_in ),(x0(2) + ((1:Bs-1)-1)*dx(2))/dy_in )
        ! end do

        iteration = 0
        call write_field(file_out, time, iteration, 1, params, lgt_block, hvy_block, lgt_active, lgt_n, hvy_n)
    end if

end subroutine block_to_blocks
