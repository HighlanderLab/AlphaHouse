!-----------------------------------------------------------------------------------------------------------------------
! The Roslin Institute, The University of Edinburgh - AlphaGenes Group
!-----------------------------------------------------------------------------------------------------------------------
!
! MODULE: CoreIndexModule
!
!> @file        CoreIndexModule.f90
!
! DESCRIPTION:
!> @brief       Module to define and read phasing rounds and their cores
!>
!> @details     This MODULE includes routines to read the information contain in the different phasing rounds located
!>              in the folder 'Phasing'
!
!> @author      Roberto Antolin, roberto.antolin@roslin.ed.ac.uk
!
!> @date        July 15, 2016
!
!> @version     0.0.1 (alpha)
!
! REVISION HISTORY:
! 2016.07.15  RAntolin - Initial Version
!
!-----------------------------------------------------------------------------------------------------------------------
MODULE CoreIndexModule
    use ISO_Fortran_Env
    implicit none
    PRIVATE


    PUBLIC getFileNameCoreIndex, getFileNameFinalPhase, getFileNameHapLib
    PUBLIC ReadCores, ReadPhased
    ! PUBLIC destroy

    INTERFACE getFileNameCoreIndex
        MODULE PROCEDURE getFileNameCoreIndex_NoPath, getFileNameCoreIndex_Path
    END INTERFACE getFileNameCoreIndex

    INTERFACE getFileNameFinalPhase
        MODULE PROCEDURE getFileNameFinalPhase_NoPath, getFileNameFinalPhase_Path
    END INTERFACE getFileNameFinalPhase

    INTERFACE getFileNameHapLib
        MODULE PROCEDURE getFileNameHapLib_NoPath, getFileNameHapLib_Path
    END INTERFACE getFileNameHapLib

    TYPE, PUBLIC :: CoreIndex
        ! PUBLIC
        integer(kind = 4), allocatable, dimension(:) :: StartSnp
        integer(kind = 4), allocatable, dimension(:) :: EndSnp
        integer(kind = 2)                            :: nCores
    CONTAINS
        ! PRIVATE
        final :: destroy_CoreIndex
    END TYPE CoreIndex

    INTERFACE CoreIndex
        MODULE PROCEDURE newCoreIndex
    END INTERFACE CoreIndex

CONTAINS


    !---------------------------------------------------------------------------
    ! DESCRIPTION:
    !> @brief      Deallocate core information
    !
    !> @details    Deallocate core information
    !
    !> @author     Roberto Antolin, roberto.antolin@roslin.ed.ac.uk
    !
    !> @date       July 15, 2016
    !
    ! PARAMETERS:
    !> @param[out] definition Core
    !---------------------------------------------------------------------------
    SUBROUTINE destroy_CoreIndex(this)
        type(CoreIndex) :: this

        if (allocated(this%StartSnp)) then
            deallocate(this%StartSnp)
        end if
        if (allocated(this%EndSnp)) then
            deallocate(this%EndSnp)
        end if
    end SUBROUTINE destroy_CoreIndex

    !---------------------------------------------------------------------------
    ! DESCRIPTION:
    !> @brief      Read core information
    !
    !> @details    Read the start and end snp for each core in the phasing round
    !
    !> @author     Roberto Antolin, roberto.antolin@roslin.ed.ac.uk
    !
    !> @date       Julyy 15, 2016
    !
    ! PARAMETERS:
    !> @param[in]  FileName  File containing the cores information
    !> @param[out] CoreI     Core information (start snp, end snp)
    !---------------------------------------------------------------------------
    FUNCTION ReadCores(FileName) result(CoreI)
        use Utils
        use AlphaHouseMod, only : countLines
        character(len=1000), intent(in) :: FileName
        type(CoreIndex)                 :: CoreI

        integer :: i
        integer :: UInputs
        character(len=20) :: dum

        CoreI = newCoreIndex(CountLines(FileName))

        ! Get core information from file
        UInputs = 111
        open (unit=UInputs,file=trim(FileName),status="old")
        do i=1,CoreI%nCores
            read (UInputs,*) dum, CoreI%StartSnp(i), CoreI%EndSnp(i)
        end do
        close(UInputs)
    END FUNCTION ReadCores

!---------------------------------------------------------------------------
! DESCRIPTION:
!> @brief      Initialise new core index
!
!> @details    Initialise new core index
!
!> @author     Roberto Antolin, roberto.antolin@roslin.ed.ac.uk
!
!> @date       Julyy 25, 2016
!
! PARAMETERS:
!> @param[inout]  CoreI  CoreIndex
!---------------------------------------------------------------------------
  FUNCTION newCoreIndex(nCores) result(this)
    integer, intent(in) :: nCores
    type(CoreIndex)     :: this

    integer :: UInputs

    this%nCores = nCores
    allocate(this%StartSnp(this%nCores))
    allocate(this%EndSnp(this%nCores))

  END FUNCTION newCoreIndex


 
! posHd returns individuals position to match up with phase
! phaseHD is obvious
    SUBROUTINE ReadPhased(nAnis, FileName, ped, PhaseHD, PosHD)
        use PedigreeModule
        use ISO_Fortran_Env
        integer, intent(in)                     :: nAnis
        character(len=*), intent(in)            :: FileName
        type(pedigreeHolder)                    ::  ped
        integer, dimension (:), intent(out)     :: PosHD
        integer, dimension (:,:,:), intent(out) :: PhaseHD

        integer :: i, j
        integer :: UPhased
        integer :: tmp
        character(len=300) :: dumC

        ! Get phase information from file
        open (newUnit=UPhased,file=trim(FileName),status="old")
        do i=1,nAnis
            read (UPhased,*) dumC,PhaseHD(i,:,1)
            read (UPhased,*) dumC,PhaseHD(i,:,2)

            tmp = ped%dictionary%getValue(trim(dumC))
            ! Match HD phase information with individuals
            if (tmp /= dict_null) then
                PosHD(tmp)=i
            else
                write(error_unit,*) "Error - phasing data has generated info for an animal that does not exist"
            endif

        enddo
        close(UPhased)
    END SUBROUTINE ReadPhased

END MODULE CoreIndexModule

