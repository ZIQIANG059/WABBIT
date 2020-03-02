!> The idea is to have small functions here, which can be useful anywhere.
!> Note you must not have any dependencies for this module (other than precision)
!> in order not to create makefile conflicts.
module module_helpers
use module_globals
use mpi
implicit none

interface smoothstep
    module procedure smoothstep1, smoothstep2
    end interface

    ! routines of the interface should be private to hide them from outside this module
    private :: smoothstep1, smoothstep2

contains

#include "most_common_element.f90"
#include "rotation_matrices.f90"

    !-----------------------------------------------------------------------------
    !> This function computes the factorial of n
    !-----------------------------------------------------------------------------
    function factorial (n) result (res)

        implicit none
        integer, intent (in) :: n
        integer :: res
        integer :: i

        res = product ((/(i, i = 1, n)/))

    end function factorial

    !-----------------------------------------------------------------------------
    !> This function computes the binomial coefficients
    !-----------------------------------------------------------------------------
    function choose (n, k) result (res)

        implicit none
        integer, intent (in) :: n
        integer, intent (in) :: k
        integer :: res

        res = factorial (n) / (factorial (k) * factorial (n - k))

    end function choose

    !-----------------------------------------------------------------------------
    !> This function returns 0 if name is not contained in list, otherwise the index for which
    !> a substring
    !-----------------------------------------------------------------------------
    function list_contains_name (list, name) result (index)

        implicit none
        character(len=*), intent (in) :: list(:)
        character(len=*), intent (in) :: name
        integer :: index

        do index = 1, size(list)
            if (trim(list(index))==trim(name))  return
        end do
        index=0
    end function list_contains_name

    !-----------------------------------------------------------------------------
    ! This function returns, to a given filename, the corresponding dataset name
    ! in the hdf5 file, following flusi conventions (folder/ux_0000.h5 -> "ux")
    !-----------------------------------------------------------------------------
    character(len=strlen)  function get_dsetname(fname)
        implicit none
        character(len=*), intent(in) :: fname
        ! extract dsetname (from "/" until "_", excluding both)
        get_dsetname  = fname  ( index(fname,'/',.true.)+1:index( fname, '_',.true. )-1 )
        return
    end function get_dsetname



    !-------------------------------------------------------------------------------
    ! evaluate a fourier series given by the coefficents a0,ai,bi
    ! at the time "time", return the function value "u" and its
    ! time derivative "u_dt". Uses assumed-shaped arrays, requires an interface.
    !-------------------------------------------------------------------------------
    subroutine fseries_eval(time,u,u_dt,a0,ai,bi)
        implicit none

        real(kind=rk), intent(in) :: a0, time
        real(kind=rk), intent(in), dimension(:) :: ai,bi
        real(kind=rk), intent(out) :: u, u_dt
        real(kind=rk) :: c,s,f
        integer :: nfft, i

        nfft=size(ai)

        ! frequency factor
        f = 2.d0*pi

        u = 0.5d0*a0
        u_dt = 0.d0

        do i=1,nfft
            s = dsin(f*dble(i)*time)
            c = dcos(f*dble(i)*time)
            ! function value
            u    = u + ai(i)*c + bi(i)*s
            ! derivative (in time)
            u_dt = u_dt + f*dble(i)*(-ai(i)*s + bi(i)*c)
        enddo
    end subroutine fseries_eval


    !-------------------------------------------------------------------------------
    ! evaluate hermite series, given by coefficients ai (function values)
    ! and bi (derivative values) at the locations x. Note that x is assumed periodic;
    ! do not include x=1.0.
    ! a valid example is x=(0:N-1)/N
    !-------------------------------------------------------------------------------
    subroutine hermite_eval(time,u,u_dt,ai,bi)
        implicit none

        real(kind=rk), intent(in) :: time
        real(kind=rk), intent(in), dimension(1:) :: ai,bi
        real(kind=rk), intent(out) :: u, u_dt
        real(kind=rk) :: dt,h00,h10,h01,h11,t, time_periodized
        integer :: n, j1,j2

        n = size(ai)

        time_periodized = time
        do while (time_periodized > 1.0_rk )
            time_periodized = time_periodized - 1.0_rk
        enddo

        dt = 1.d0 / dble(n)
        j1 = floor(time_periodized/dt) + 1
        j2 = j1 + 1
        ! periodization
        if (j2 > n) j2 = 1
        ! normalized time (between two data points)
        t = (time_periodized-dble(j1-1)*dt) /dt

        ! values of hermite interpolant
        h00 = (1.d0+2.d0*t)*((1.d0-t)**2)
        h10 = t*((1.d0-t)**2)
        h01 = (t**2)*(3.d0-2.d0*t)
        h11 = (t**2)*(t-1.d0)

        ! function value
        u = h00*ai(j1) + h10*dt*bi(j1) + h01*ai(j2) + h11*dt*bi(j2)

        ! derivative values of basis functions
        h00 = 6.d0*t**2 - 6.d0*t
        h10 = 3.d0*t**2 - 4.d0*t + 1.d0
        h01 =-6.d0*t**2 + 6.d0*t
        h11 = 3.d0*t**2 - 2.d0*t

        ! function derivative value
        u_dt = (h00*ai(j1) + h10*dt*bi(j1) + h01*ai(j2) + h11*dt*bi(j2) ) / dt
    end subroutine hermite_eval



    function mpisum( a )
        implicit none
        real(kind=rk) :: a_loc, mpisum
        real(kind=rk),intent(in) :: a
        integer :: mpicode
        a_loc=a
        call MPI_ALLREDUCE (a_loc,mpisum,1, MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,mpicode)
    end function

    function mpisum_i( a )
        implicit none
        integer(kind=ik) :: a_loc, mpisum_i
        integer(kind=ik),intent(in) :: a
        integer :: mpicode
        a_loc=a
        call MPI_ALLREDUCE (a_loc,mpisum_i,1, MPI_INTEGER4,MPI_SUM,MPI_COMM_WORLD,mpicode)
    end function

    function mpimax( a )
        implicit none
        real(kind=rk) :: a_loc, mpimax
        real(kind=rk),intent(in) :: a
        integer :: mpicode
        a_loc=a
        call MPI_ALLREDUCE (a_loc,mpimax,1, MPI_DOUBLE_PRECISION,MPI_MAX,MPI_COMM_WORLD,mpicode)
    end function

    function mpimin( a )
        implicit none
        real(kind=rk) :: a_loc, mpimin
        real(kind=rk),intent(in) :: a
        integer :: mpicode
        a_loc=a
        call MPI_ALLREDUCE (a_loc,mpimin,1, MPI_DOUBLE_PRECISION,MPI_MIN,MPI_COMM_WORLD,mpicode)
    end function

    real (kind=rk) function interp2_nonper (x_target, y_target, field2, axis)
        !  LINEAR Interpolation in a field. The field is of automatic size, indices starting with 0 both. The domain is
        !  defined by x1_box,y1_box and x2_box,y2_box. The target coordinates should lie within that box.
        !  NOTE: attention on the upper point of the box. In the rest of the code, which is periodic, the grid is 0:nx-1
        !        but the lattice spacing is yl/nx. This means that the point (nx-1) has NOT the coordinate yl but yl-dx
        !        (otherwise this point would exist two times!)
        implicit none
        integer :: i,j
        real (kind=rk) :: x,y,x_1,y_1,x_2,y_2,dx, dy, R1,R2
        real (kind=rk), intent (in) :: field2(0:,0:), x_target, y_target, axis(1:4)
        real(kind=rk) :: x1_box, y1_box, x2_box, y2_box

        x1_box = axis(1)
        x2_box = axis(2)
        y1_box = axis(3)
        y2_box = axis(4)


        dx = (x2_box-x1_box) / dble(size(field2,1)-1 )
        dy = (y2_box-y1_box) / dble(size(field2,2)-1 )


        if ( (x_target > x2_box).or.(x_target < x1_box).or.(y_target > y2_box).or.(y_target < y1_box) ) then
            ! return zero if point lies outside valid bounds
            interp2_nonper = 0.0d0
            return
        endif

        i = int((x_target-x1_box)/dx)
        j = int((y_target-y1_box)/dy)

        x_1 = dble(i)*dx + x1_box
        y_1 = dble(j)*dy + y1_box
        x_2 = dx*dble(i+1) + x1_box
        y_2 = dy*dble(j+1) + y1_box
        R1 = (x_2-x_target)*field2(i,j)/dx   + (x_target-x_1)*field2(i+1,j)/dx
        R2 = (x_2-x_target)*field2(i,j+1)/dx + (x_target-x_1)*field2(i+1,j+1)/dx

        interp2_nonper = (y_2-y_target)*R1/dy + (y_target-y_1)*R2/dy

    end function interp2_nonper


    real(kind=rk) function startup_conditioner(time, time_release, tau)

        !---------------------------------------------------------------------------------------------
        ! modules
        use module_precision
        !---------------------------------------------------------------------------------------------
        ! variables

        implicit none

        real(kind=rk), intent(in)  :: time,time_release, tau
        real(kind=rk)              :: dt
        !---------------------------------------------------------------------------------------------
        ! main body

        dt = time-time_release

        if (time <= time_release) then
            startup_conditioner = 0.0_rk
        elseif ( ( time >time_release ).and.(time<(time_release + tau)) ) then
            startup_conditioner =  (dt**3)/(-0.5_rk*tau**3) + 3.0_rk*(dt**2)/tau**2
        else
            startup_conditioner = 1.0_rk
        endif

        return
    end function startup_conditioner

    !==========================================================================
    !> \brief This subroutine returns the value f of a smooth step function \n
    !> The sharp step function would be 1 if delta<=0 and 0 if delta>0 \n
    !> h is the semi-size of the smoothing area, so \n
    !> f is 1 if delta<=0-h \n
    !> f is 0 if delta>0+h \n
    !> f is variable (smooth) in between
    !> \details
    !> \image html maskfunction.bmp "plot of chi(delta)"
    !> \image latex maskfunction.eps "plot of chi(delta)"
    function smoothstep1(delta,h)
        use module_precision
        implicit none
        real(kind=rk), intent(in)  :: delta,h
        real(kind=rk)              :: smoothstep1,f
        !-------------------------------------------------
        ! cos shaped smoothing (compact in phys.space)
        !-------------------------------------------------
        if (delta<=-h) then
            f = 1.0_rk
        elseif ( -h<delta .and. delta<+h  ) then
            f = 0.5_rk * (1.0_rk + dcos((delta+h) * pi / (2.0_rk*h)) )
        else
            f = 0.0_rk
        endif

        smoothstep1=f
    end function smoothstep1
    !==========================================================================


    function smoothstep2(x,t,h)
        !-------------------------------------------------------------------------------
        !> This subroutine returns the value f of a smooth step function \n
        !> The sharp step function would be 1 if x<=t and 0 if x>t \n
        !> h is the semi-size of the smoothing area, so \n
        !> f is 1 if x<=t-h \n
        !> f is 0 if x>t+h \n
        !> f is variable (smooth) in between
        !-------------------------------------------------------------------------------
        use module_precision

        implicit none
        real(kind=rk), intent(in)  :: x,t,h
        real(kind=rk)              :: smoothstep2

        !-------------------------------------------------
        ! cos shaped smoothing (compact in phys.space)
        !-------------------------------------------------
        if (x<=t-h) then
            smoothstep2 = 1.0_rk
        elseif (((t-h)<x).and.(x<(t+h))) then
            smoothstep2 = 0.5_rk * (1.0_rk + dcos((x-t+h) * pi / (2.0_rk*h)) )
        else
            smoothstep2 = 0.0_rk
        endif

    end function smoothstep2

    ! abort program if file does not exist
    subroutine check_file_exists(fname)
        implicit none

        character (len=*), intent(in) :: fname
        logical :: exist1

        inquire ( file=fname, exist=exist1 )
        if ( exist1 .eqv. .false.) then
            write (*,'("ERROR! file: ",A," not found")') trim(adjustl(fname))
            call abort( 191919, "File not found...."//trim(adjustl(fname)) )
        endif

    end subroutine check_file_exists

    !---------------------------------------------------------------------------
    ! wrapper for NaN checking (this may be compiler dependent)
    !---------------------------------------------------------------------------
    logical function is_nan( x )
        implicit none
        real(kind=rk) :: x
        is_nan = .false.
        if (.not. (x.eq.x)) is_nan=.true.
    end function is_nan

    logical function block_contains_NaN(data)
        ! check for one block if a certain datafield contains NaNs
        implicit none
        real(kind=rk), intent(in)       :: data(:,:,:)
        integer(kind=ik)                :: nx, ny, nz, ix, iy, iz

        nx = size(data,1)
        ny = size(data,2)
        nz = size(data,3)

        block_contains_NaN = .false.
        do iz=1,nz
            do iy=1,ny
                do ix=1,nx
                    if (is_nan(data(ix,iy,iz))) block_contains_NaN=.true.
                end do
            end do
        end do
    end function block_contains_NaN

    ! fill a 4D array of any size with random numbers
    subroutine random_data( field )
        real(kind=rk), intent(inout) :: field(1:,1:,1:,1:)
        integer :: ix,iy,iz,id

        do id = 1, size(field,4)
            do iz = 1, size(field,3)
                do iy = 1, size(field,2)
                    do ix = 1, size(field,1)
                        field(ix,iy,iz,id) = rand_nbr()
                    enddo
                enddo
            enddo
        enddo
    end subroutine

    !-------------------------------------------------------------------------------
    ! runtime control routines
    ! flusi regularily reads from a file runtime_control.ini if it should do some-
    ! thing, such as abort, reload_params or save data.
    !-------------------------------------------------------------------------------
    subroutine Initialize_runtime_control_file()
        ! overwrites the file again with the standard runtime_control file
        implicit none

        open  (14,file='runtime_control',status='replace')
        write (14,'(A)') "# This is wabbit's runtime control file"
        write (14,'(A)') "# Stop the run but makes a backup first"
        write (14,'(A)') "# Memory is properly dealloacted, unlike KILL"
        write (14,'(A)') "#       runtime_control=save_stop;"
        write (14,'(A)') ""
        write (14,'(A)') "[runtime_control]"
        write (14,'(A)') "runtime_control=nothing;"
        close (14)

    end subroutine Initialize_runtime_control_file


    logical function runtime_control_stop(  )
        ! reads runtime control command
        use module_ini_files_parser_mpi
        implicit none
        character(len=80) :: command
        character(len=80) :: file
        type(inifile) :: CTRL_FILE

        file ="runtime_control"

        ! root reads in the control file
        ! and fetched the command
        call read_ini_file_mpi( CTRL_FILE, file, .false. ) ! false = non-verbose
        call read_param_mpi(CTRL_FILE, "runtime_control","runtime_control", command, "none")
        call clean_ini_file_mpi( CTRL_FILE )

        if (command == "save_stop") then
            runtime_control_stop = .true.
        else
            runtime_control_stop = .false.
        endif
    end function runtime_control_stop


    ! source: http://fortranwiki.org/fortran/show/String_Functions
    FUNCTION str_replace_text (s,text,rep)  RESULT(outs)
        CHARACTER(*)        :: s,text,rep
        CHARACTER(LEN(s)+100) :: outs     ! provide outs with extra 100 char len
        INTEGER             :: i, nt, nr

        outs = s ; nt = LEN_TRIM(text) ; nr = LEN_TRIM(rep)
        DO
            i = INDEX(outs,text(:nt)) ; IF (i == 0) EXIT
            outs = outs(:i-1) // rep(:nr) // outs(i+nt:)
        END DO
    END FUNCTION str_replace_text


    !-------------------------------------------------------------------------!
    !> @brief remove (multiple) blancs as separators in a string
    subroutine merge_blanks(string_merge)
        ! this routine removes blanks at the beginning and end of an string
        ! and multiple blanks which are right next to each other

        implicit none
        character(len=*), intent(inout) :: string_merge
        integer(kind=ik) :: i, j, len_str, count

        len_str = len(string_merge)
        count = 0

        string_merge = string_merge
        do i=1,len_str-1
            if (string_merge(i:i)==" " .and. string_merge(i+1:i+1)==" ") then
                count = count + 1
                string_merge(i+1:len_str-1) = string_merge(i+2:len_str)
            end if
        end do

        string_merge = adjustl(string_merge)

    end subroutine merge_blanks



    !-------------------------------------------------------------------------!
    !> @brief count number of vector elements in a string
    subroutine count_entries(string_cnt, n_entries)
        ! only to be used after merged blaks
        ! this routine counts the separators and gives back this value +1

        implicit none
        character(len=1) :: separator
        character(len=*), intent(in) :: string_cnt
        integer(kind=ik), intent(out) :: n_entries
        integer(kind=ik) :: count_separator, i, l_string
        character(len=len_trim(adjustl(string_cnt))):: string_trim

        string_trim = trim(adjustl( string_cnt ))
        call merge_blanks(string_trim)
        string_trim = trim(adjustl( string_trim ))

        l_string = len_trim(string_trim)

        ! we now have reduced the number of b blanks to at most one at the time: "hdj    aa" => "hdj aa"
        ! NOW: we figure out if the values are separated by spaces " " or commas "," or ";"
        separator = " "
        if (index(string_trim, ",") /= 0) separator=","
        if (index(string_trim, ";") /= 0) separator=";"

        count_separator = 0
        do i = 1, l_string
            if (string_trim(i:i) == separator) then
                count_separator = count_separator + 1
            end if
        end do

        n_entries = count_separator + 1

    end subroutine count_entries

    !---------------------------------------------------------------------------
    ! Command-line argument parser. You can parse stuff like:
    ! ./program --hallo=10.4
    ! ./program --deine="10.4"
    ! ./program --mutter="ux_00.h5, uy_00.h5"
    ! ./program --vater="ux_00.h5,uy_00.h5"
    ! ./program --kind="ux_00.h5 uy_00.h5"
    !---------------------------------------------------------------------------
    ! There is no "ordering" so the args can be put in any order when calling the program.
    ! You can pass a default value which is used if the parameter is not given in the call.
    ! The parser removes quotes " from the data
    !---------------------------------------------------------------------------
    ! Form in command line:
    ! --name=3.0    (returns 3.0)
    ! alternatively:
    ! --name="3.0, 7.0"  (returns 3.0, 7.0) (remove delimiters)
    subroutine get_cmd_arg_str( name, value, default )
        implicit none
        character(len=*), intent(in) :: name
        character(len=*), intent(in) :: default
        character(len=80), intent(out) :: value

        integer :: i, rank, ierr
        character(len=120) :: args

        value = default
        call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)

        do i = 1, command_argument_count()
            call get_command_argument(i,args)

            if (index(args, trim(adjustl(name))//"=") /= 0) then
                value = str_replace_text( args, trim(adjustl(name))//"=", "")
                value = str_replace_text( value, '"', '')

                if (rank == 0) then
                    write(*,*) "COMMAND-LINE-PARAMETER: read "//trim(adjustl(name))//" = "//trim(adjustl(value))
                endif

                return
            endif

        enddo

        if (rank == 0) then
            write(*,*) "COMMAND-LINE-PARAMETER: read "//trim(adjustl(name))//" = "//trim(adjustl(value))//" THIS IS THE DEFAULT!"
        endif

    end subroutine

    !---------------------------------------------------------------------------
    ! Command-line argument parser. You can parse stuff like:
    ! ./program --hallo=10.4
    ! ./program --deine="10.4"
    ! ./program --mutter="ux_00.h5, uy_00.h5"
    ! ./program --vater="ux_00.h5,uy_00.h5"
    ! ./program --kind="ux_00.h5 uy_00.h5"
    !---------------------------------------------------------------------------
    ! There is no "ordering" so the args can be put in any order when calling the program.
    ! You can pass a default value which is used if the parameter is not given in the call.
    ! The parser removes quotes " from the data
    !---------------------------------------------------------------------------
    ! Form in command line:
    ! --name=3.0    (returns 3.0)
    ! alternatively:
    ! --name="3.0, 7.0"  (returns 3.0, 7.0) (remove delimiters)
    subroutine get_cmd_arg_str_vct( name, value )
        implicit none
        character(len=*), intent(in) :: name
        character(len=80), intent(out), ALLOCATABLE :: value(:)

        integer :: i, rank, ierr, n, k
        character(len=120) :: args


        call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)

        do i = 1, command_argument_count()
            call get_command_argument(i, args)

            if (index(args, trim(adjustl(name))//"=") /= 0) then
                ! remove the string "--name="
                args = str_replace_text( args, trim(adjustl(name))//"=", "")
                ! remove str delimiter "
                args = str_replace_text( args, '"', '')
                ! count number of vector entries
                call count_entries(args, n)

                allocate( value(1:n) )

                if (n == 1) then
                    read(args, '(A)') value(1)(:)
                else
                    read(args, *) value
                end if

                if (rank == 0) then
                    write(*,'(" COMMAND-LINE-PARAMETER: read ",A," length=",i2)') trim(adjustl(name)), n
                    write(*,'(A)') args
                    write(*,'(A,1x)') ( trim(adjustl(value(k))), k=1, n)
                endif

                return
            endif

        enddo

    end subroutine

    !---------------------------------------------------------------------------
    ! Command-line argument parser. You can parse stuff like:
    ! ./program --hallo=10.4
    ! ./program --deine="10.4"
    ! ./program --mutter="ux_00.h5, uy_00.h5"
    ! ./program --vater="ux_00.h5,uy_00.h5"
    ! ./program --kind="ux_00.h5 uy_00.h5"
    !---------------------------------------------------------------------------
    ! There is no "ordering" so the args can be put in any order when calling the program.
    ! You can pass a default value which is used if the parameter is not given in the call.
    ! The parser removes quotes " from the data
    !---------------------------------------------------------------------------
    ! Form in command line:
    ! --name=3.0    (returns 3.0)
    ! alternatively:
    ! --name="3.0, 7.0"  (returns 3.0, 7.0) (remove delimiters)
    subroutine get_cmd_arg_int( name, value, default )
        implicit none
        character(len=*), intent(in) :: name
        integer(kind=ik), intent(in) :: default
        integer(kind=ik), intent(out) :: value

        integer :: i, rank, ierr
        character(len=120) :: args
        integer :: iostat

        call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)

        do i = 1, command_argument_count()
            call get_command_argument(i,args)

            if (index(args, trim(adjustl(name))//"=") /= 0) then
                args = str_replace_text( args, trim(adjustl(name))//"=", "")
                args = str_replace_text( args, '"', '')

                read(args, *, iostat=iostat) value

                if (iostat /= 0) then
                    write(*,*) " COMMAND-LINE-PARAMETER: read "//trim(adjustl(name))//" = "//trim(adjustl(args))
                    call abort(200302018, "Failed to convert to INTEGER.")
                endif

                if (rank == 0) then
                    write(*,'(" COMMAND-LINE-PARAMETER: read ",A," = ",i8)') trim(adjustl(name)), value
                endif

                return
            endif

        enddo

        value = default
        if (rank == 0) then
            write(*,'("COMMAND-LINE-PARAMETER: read ",A," = ",i8," THIS IS THE DEFAULT!")') trim(adjustl(name)), value
        endif

    end subroutine

    !---------------------------------------------------------------------------
    ! Command-line argument parser. You can parse stuff like:
    ! ./program --hallo=10.4
    ! ./program --deine="10.4"
    ! ./program --mutter="ux_00.h5, uy_00.h5"
    ! ./program --vater="ux_00.h5,uy_00.h5"
    ! ./program --kind="ux_00.h5 uy_00.h5"
    !---------------------------------------------------------------------------
    ! There is no "ordering" so the args can be put in any order when calling the program.
    ! You can pass a default value which is used if the parameter is not given in the call.
    ! The parser removes quotes " from the data
    !---------------------------------------------------------------------------
    ! Form in command line:
    ! --name=3.0    (returns 3.0)
    ! alternatively:
    ! --name="3.0, 7.0"  (returns 3.0, 7.0) (remove delimiters)
    subroutine get_cmd_arg_dbl( name, value, default )
        implicit none
        character(len=*), intent(in) :: name
        real(kind=rk), intent(in) :: default
        real(kind=rk), intent(out) :: value

        integer :: i, rank, ierr
        character(len=120) :: args
        integer :: iostat

        call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)

        do i = 1, command_argument_count()
            call get_command_argument(i,args)

            if (index(args, trim(adjustl(name))//"=") /= 0) then
                args = str_replace_text( args, trim(adjustl(name))//"=", "")
                args = str_replace_text( args, '"', '')

                read(args, *, iostat=iostat) value

                if (iostat /= 0) then
                    write(*,*) " COMMAND-LINE-PARAMETER: read "//trim(adjustl(name))//" = "//trim(adjustl(args))
                    call abort(200302017, "Failed to convert to DOUBLE.")
                endif

                if (rank == 0) then
                    write(*,'(" COMMAND-LINE-PARAMETER: read ",A," = ",g15.8)') trim(adjustl(name)), value
                endif

                return
            endif

        enddo

        value = default
        if (rank == 0) then
            write(*,'(" COMMAND-LINE-PARAMETER: read ",A," = ",g15.8," THIS IS THE DEFAULT!")') trim(adjustl(name)), value
        endif

    end subroutine

end module module_helpers
