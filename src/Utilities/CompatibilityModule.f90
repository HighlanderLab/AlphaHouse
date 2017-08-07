
!###############################################################################

!-------------------------------------------------------------------------------
! The Roslin Institute, The University of Edinburgh - AlphaGenes Group
!-------------------------------------------------------------------------------
!
!> @file     CompatibilityModule.f90
!
! DESCRIPTION:
!> @brief    Module cotaining subroutines to deal with text PLINK format
!> @details  currently only contains integer and real heap sort procedures 
!
!> @author   David Wilson, david.wilson@roslin.ed.ac.uk
!
!> @date     January 4, 2017
!
!> @version  1.0.0
!
!
!-------------------------------------------------------------------------------






function readToPedigreeFormat(pedFile) result(ped)
    use ConstantModule, only : IDLENGTH
    use AlphaHouseMod, only : countLines
    use PedigreeModule

    type(pedigreeHolder) :: ped !< Pedigree object that is returned
    character(len=*), intent(in) :: pedFile !< .ped file generated by plink
    character(len=IDLENGTH) :: familyID,gender,phenotype
    integer :: fileUnit,stat, i,lines
    character(len=IDLENGTH),dimension(:,:), allocatable :: pedArray
    integer, allocatable, dimension(:) :: genderArray, phenotypeArray

    lines=  countLines(pedFile)
   
    allocate(pedArray(3,lines))
    allocate(genderArray(lines))
    allocate(phenotypeArray(lines))                
    
    open(newUnit=fileUnit, file=pedFile, status="old")
    do i=1, lines
        read(fileUnit,*) familyID,pedArray(1,i),pedArray(2,i),pedArray(3,i),gender,phenotype

        read(gender,*,iostat=stat)  genderArray(i)
        read(phenotype,*,iostat=stat)  phenotypeArray(i)
    enddo


    ped = PedigreeHolder(pedArray, genderArray)



end function readToPedigreeFormat


subroutine readPlink(binaryFilePre, outfile, missing, ped)
    use AlphaHouseMod, only : CountLines

    character(len=*),intent(in) :: binaryFilePre, outfile,missing
    integer :: fam,bim,bed
    integer, allocatable
    open(newUnit=fam, file=binaryFilePre//".fam", status='old')
    open(newUnit=bim, file=binaryFilePre//".bim", status='old')
    open(newUnit=bd, file=binaryFilePre//".bed", status='old')

    ped = readToPedigreeFormat(binaryFilePre//".fam")


! Stores entire genotype file in memory
subroutine readplinkIntoPedigree(bed, ncol, nlines, na, ped, minor, maf, extract, keep, status)
  
  implicit none

  ! Arguments  
  character(255), intent(in) :: bed
  integer, intent(in) :: ncol, nlines, na, minor
  integer, dimension(nlines), intent(in) :: newID, keep
  integer, dimension(ncol), intent(in) :: extract
  integer, intent(out) :: status
  type(PedigreeHolder), intent(inout) :: ped
  double precision, intent(in) :: maf
  
  !! Types
  INTEGER, PARAMETER :: Byte = SELECTED_INT_KIND(1) ! Byte
  
  !! Local arguments
  integer(Byte) :: readplinkmode, element, plinkmode
  integer(Byte), dimension(2) :: readmagicnumber, magicnumber
  !logical :: checkmaf
  logical, dimension(ncol) :: masksnps
  integer :: stat, i, j, k, snpcount, majorcount
  integer, dimension(4) :: codes
  !integer, dimension(:), allocatable :: domasksnps
  integer, dimension(:,:), allocatable :: snps, masked
  real :: allelefreq
  character(100) :: nChar, fmt
  
  integer :: bedInUnit
  ! Supported formats as per plink 1.9.
  !data magicnumber/X"6C",X'0000001B' /,  plinkmode/X'01'/
  data magicnumber /108,27/, plinkmode /1/
  
  allocate(snps(nlines,ncol))
  snps(:,:) = 9
  
  masksnps=extract==1
  
  if (minor == 1) then
    codes = (/ 0, 1, 2, na /)
  else
    codes = (/ 2, 1, 0, na /)
  endif
  
  open(bedInUnit, file=bed, status='OLD', ACCESS='STREAM', FORM='UNFORMATTED')
  read(bedInUnit) readmagicnumber, readplinkmode
  if (all(readmagicnumber /= magicnumber) ) then
    status=-1
    close(bedInUnit)
    return
  endif
  if (readplinkmode /= plinkmode) then
    status=-2
    close(bedInUnit)
    return
  endif


  j=0  ! Sample-index
  k=1  ! SNP-index
  snpcount = 0
  majorcount = 0
  outer: do 
    read(bedInUnit, iostat=stat) element
    if (stat /= 0) exit
    inner: do i=0,6,2
      j = j + 1
      snpcount = snpcount + 1
      select case(IBITS(element, i, 2))
        case (0) ! homozygote
          snps(j,k) = codes(1)
        case (1) ! missing
          snps(j,k) = codes(4)
          snpcount = snpcount - 1
        case (2) ! heterozygote
          snps(j,k) = codes(2)
          majorcount = majorcount + 1
        case (3) ! homozygote, minor
          snps(j,k) = codes(3)
          majorcount = majorcount + 2
      endselect
      if (j == nlines) then
        if (snpcount /= 0) then
          allelefreq = majorcount / (snpcount*2.)
          masksnps(k) = masksnps(k) .and. allelefreq .ge. maf .and. allelefreq .le. (1-maf)
        endif
        j = 0
        snpcount = 0
        majorcount = 0
        k = k + 1
        cycle outer
      endif
    enddo inner
  enddo outer
  close(bedInUnit)
  
  if (stat == -1) stat=0
  
  ! Write output
  write(nChar,*) count(masksnps)
  fmt='(i20,'//trim(adjustl(nChar))//'I2)'
  !print *, fmt
  


  pack(snps(i,:), masksnps)
  do i=1,nlines
    ped%pedigree(i)%individualGenotype = NewGenotypeInt(pack(snps(i,:), masksnps))
  enddo

  deallocate(snps)
  status=stat
  
  !print *, 'readplinksimple is done.'
  
end subroutine readplinkIntoPedigree



