#ifdef _WIN32

#define STRINGIFY(x)#x
#define TOSTRING(x) STRINGIFY(x)

#DEFINE DASH "\"
#DEFINE COPY "copy"
#DEFINE MD "md"
#DEFINE RMDIR "RMDIR /S /Q"
#DEFINE RM "del"
#DEFINE RENAME "MOVE /Y"
#DEFINE SH "BAT"
#DEFINE EXE ".exe"
#DEFINE NULL " >NUL"


#else

#define STRINGIFY(x)#x
#define TOSTRING(x) STRINGIFY(x)

#DEFINE DASH "/"
#DEFINE COPY "cp"
#DEFINE MD "mkdir"
#DEFINE RMDIR "rm -r"
#DEFINE RM "rm"
#DEFINE RENAME "mv"
#DEFINE SH "sh"
#DEFINE EXE ""
#DEFINE NULL ""


#endif
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
module CompatibilityModule
	use integerLinkedListModule
	use HashModule
	use PedigreeModule

	type bimHolder
	character(len=1) :: ref,alt
	character(len=IDLENGTH) :: id
	character(len=2) :: chrom !<either an integer, or 'X'/'Y'/'XY'/'MT'
	integer(kind=int64) :: pos, chrompos
end type bimHolder

type Chromosome

type(integerLinkedList) :: snps
contains
	final :: destroyChrom
end type Chromosome
contains

	subroutine destroyChrom(chrom)


		type(Chromosome) :: chrom

		call chrom%snps%destroyLinkedList()

	end subroutine





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
		print *,"TOTAL ANS",lines
		do i=1, lines
			read(fileUnit,*) familyID,pedArray(1,i),pedArray(2,i),pedArray(3,i),gender,phenotype


			! write(*,'(3a20)') pedArray(1,i),pedArray(2,i),pedArray(3,i)
			read(gender,*,iostat=stat)  genderArray(i)
			read(phenotype,*,iostat=stat)  phenotypeArray(i)
		enddo


		ped = PedigreeHolder(pedArray, genderArray)

		call ped%printPedigreeOriginalFormat("pedigreeOutput.txt")

	end function readToPedigreeFormat


	subroutine readPlink(binaryFilePre, ped, outputPaths,nsnps, sexChrom)
		use HashModule
		use AlphaHouseMod, only : CountLines
		use PedigreeModule
		use ifport

		character(len=*),intent(in) :: binaryFilePre
		type(pedigreeholder), intent(out) :: ped
		logical, intent(out) :: sexChrom
		type(DictStructure) :: dict
		integer:: maxChroms
		type(bimHolder) , allocatable, dimension(:) :: bimInfo
		type(Chromosome), dimension(:), allocatable :: chroms
		logical, dimension(:), allocatable :: maskedLogi
		integer, dimension(:), allocatable :: masked
		character(len=100) :: fmt
		integer(kind=1), dimension(:,:), allocatable ::  allsnps
		character(len=128) :: path, outChrFile
		character(len=128), dimension(:), allocatable :: outputPaths
		integer result,i,p,h,outChrF, maxSnps
		integer,dimension(:), allocatable, intent(out) :: nsnps
		! integer, allocatable


		ped = readToPedigreeFormat(trim(binaryFilePre)//".fam")

	call readBim(trim(binaryFilePre)//".bim",dict,bimInfo,nsnps,maxSnps,chroms,maxChroms, sexChrom)
		print *,"READ BIM"
		call readplinkSnps(trim(binaryFilePre)//".bed",maxSnps,ped,1, allsnps)
		print *,"READ BED"
		allocate(maskedLogi(size(allSnps(1,:))))


		! nsnps = size(allSnps(1,:))
		path = "chromosomeGenotypes/"
		result=makedirqq(path)

		print *, "MAX CHROMS",maxChroms

		allocate(outputPaths(maxChroms))
		do i =1, maxChroms
			write(outChrFile, '(a,a,i0.2)') trim(path),trim("chr"),i
			outputPaths(i) = outChrFile
			open(newunit=outChrF, file=trim(outChrFile)//"genotypes.txt", status="unknown")
			masked = chroms(i)%snps%convertToArray()
			maskedLogi = .false.
			do h =1, size(masked)
				maskedLogi(masked(h)) = .true.

			enddo
			write(fmt, '(a,i10,a)')  "(a20,", nsnps(i), "i2)"
			do p=1,ped%pedigreeSize-ped%nDummys
				write(outChrF,fmt) ped%pedigree(p)%originalId,pack(allSnps(p,:), maskedLogi)
			end do
			close(outChrF)
		enddo

		call dict%destroy()
	end subroutine readPlink







	subroutine readBim(bimFile, dict, bimInfo,nsnps,maxSnps,chroms, maxChroms, hasSexChrom)
		use HashModule
		use AlphaHouseMod
		use ConstantModule

		character(len=*), intent(in) :: bimFile
		type(DictStructure) :: dict
		logical, intent(out) :: hasSexChrom 
		character :: ref,alt
		character(len=IDLENGTH) :: id

		integer(kind=int64) :: pos, chrompos


		integer,intent(out) :: maxSnps
		integer,intent(out), dimension(:), allocatable :: nsnps
		integer, dimension(:), allocatable :: temparray
		integer,intent(out) :: maxChroms

		integer :: i, unit,chromCount,curChromSnpCount
		type(bimHolder) , allocatable, dimension(:), intent(out) :: bimInfo
		type(Chromosome),dimension(:), allocatable, intent(out) :: chroms
		character(len=2) :: chrom,prevChrom

		maxChroms = 0
		hasSexChrom = .false.
		curChromSnpCount = 0 
		allocate(nsnps(LARGECHROMNUMBER))
		nsnps = 0
		dict = DictStructure()
		maxSnps = countLines(bimFile)

		open(newUnit=unit, file=bimFile, status='old')
		allocate(chroms(LARGECHROMNUMBER))
		allocate(bimInfo(maxSnps))
		chromCount = 1
		do i =1, maxSnps

			read(unit, *) chrom, id,chrompos, pos ,ref, alt

			if (i == 1) then
				prevChrom = chrom
			endif
				
			! if we've moved on to the next chromsome
			if (chrom == "X" .or. chrom == 'Y') then
				hasSexChrom = .true.
			endif
			
			if (chrom == 'XY' .or. chrom == 'MT') then
				write(error_unit,*) "WARNING - No support currently for XY or MT chromosomes"
			endif
				
			if (chrom /=prevChrom) then

				! set the count to he current numbers
				nsnps(chromCount) = curChromSnpCount
				print *,"HEREEEE",chromCount, nsnps(chromCount),chrom, prevChrom
				curChromSnpCount = 0
				chromCount = chromCount + 1

				prevChrom = chrom
				if (chromCount > maxChroms) then
					maxChroms = chromCount
				endif
			endif
			curChromSnpCount = curChromSnpCount + 1 
			call dict%addKey(id, i)
			bimInfo(i)%chrom = chrom
			!  TODO what does this do!???

			bimInfo(i)%id = id


			bimInfo(i)%chrompos = chrompos
			bimInfo(i)%pos = pos
			bimInfo(i)%ref = ref
			bimInfo(i)%alt = alt

			call chroms(chromCount)%snps%list_add(i)
		end do

		! maxChroms = maxChroms -1

		if (chromCount /= LARGECHROMNUMBER) then
            allocate(temparray(chromCount))
            temparray(1:chromCount) = nsnps(1:chromCount)
            call move_alloc(temparray,nsnps)
        endif
		close (unit)


	end subroutine readBim

	! Stores entire genotype file in memory
	subroutine readplinkSnps(bed, ncol,ped, minor,snps)

		use PedigreeModule
		use genotypeModule
		implicit none

		! Arguments
		character(*), intent(in) :: bed
		integer, intent(in) :: ncol, minor
		integer :: status
		type(PedigreeHolder), intent(in) :: ped

		!! Types
		INTEGER, PARAMETER :: Byte = SELECTED_INT_KIND(1) ! Byte

		!! Local arguments
		integer(Byte) :: readplinkmode, element, plinkmode
		integer(Byte), dimension(2) :: readmagicnumber, magicnumber
		!logical :: checkmaf
		integer :: stat, i, j, k, snpcount, majorcount
		integer, dimension(4) :: codes
		!integer, dimension(:), allocatable :: domasksnps
		integer(kind=1), dimension(:,:), allocatable,intent(out) ::  snps
		real :: allelefreq
		integer :: na
		integer :: bedInUnit
		! Supported formats as per plink 1.9.
		!data magicnumber/X"6C",X'0000001B' /,  plinkmode/X'01'/
		data magicnumber /108,27/, plinkmode /1/


		print *,"start BED read"
		allocate(snps(ped%pedigreeSize-ped%nDummys,ncol))

		na = 9
		snps(:,:) = 9


		if (minor == 1) then
			codes = (/ 0, 1, 2, na /)
		else
			codes = (/ 2, 1, 0, na /)
		endif

		open(newunit=bedInUnit, file=bed, status='OLD', ACCESS='STREAM', FORM='UNFORMATTED')
		print *, "start read"
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
				if (j == ped%pedigreeSize-ped%nDummys) then
					if (snpcount /= 0) then
						allelefreq = majorcount / (snpcount*2.)
					endif
					j = 0
					snpcount = 0
					majorcount = 0
					k = k + 1
					cycle outer
				endif
			enddo inner
			! print *, "in outer"
		enddo outer
		close(bedInUnit)

		if (stat == -1) stat=0

		print *, "finished"


		! Write output
		! fmt='(i20,'//trim(adjustl(nChar))//'I2)'
		!print *, fmt



		! do i=1,nlines
		! 	ped%pedigree(i)%individualGenotype = NewGenotypeInt(pack(snps(i,:), masksnps))
		! enddo

		! deallocate(snps)

		!print *, 'readplinksimple is done.'

	end subroutine readplinkSnps


	subroutine readPlinkNoneBinary(filePre,ped,outputPaths ,nsnps,sexChrom)
		use HashModule
		use PedigreeModule
		use AlphaHouseMod
		use ifport

		character(len=*),intent(in) :: filePre
		character(len=128), dimension(:), allocatable,intent(out) :: outputPaths
		integer, dimension(:) ,allocatable :: nsnps
		integer :: totalSnps,outChrF
		type(Chromosome), dimension(:), allocatable :: chroms
		logical,intent(out) :: sexChrom
		character(len=128) :: path, outChrFile
		integer(kind=1), dimension(:,:), allocatable ::  genotypes
		logical, dimension(:), allocatable :: maskedLogi
		integer, dimension(:), allocatable :: masked
		integer :: i,h,maxChroms,maxSnps,result,p
		character(100) :: fmt
		type(DictStructure) :: dict
		type(pedigreeHolder) :: ped

		call readMap(trim(filePre)//".map", dict,chroms,maxChroms, nsnps, totalSnps,sexChrom)
		
		allocate(maskedLogi(totalSnps))
		
		call readPedFile(trim(filePre)//".ped",ped, maxSnps, genotypes, "refAlleles.txt")
		path = "chromosomeGenotypes/"
		result=makedirqq(path)

		print *, "MAX CHROMS",maxChroms

		allocate(outputPaths(maxChroms))
		do i =1, maxChroms
			write(outChrFile, '(a,a,i2,a)') trim(path),trim("chr"),i,DASH
			outputPaths(i) = outChrFile
			open(newunit=outChrF, file=trim(outChrFile)//"genotypes.txt", status="unknown")
			masked = chroms(i)%snps%convertToArray()
			maskedLogi = .false.
			do h =1, size(masked)
				maskedLogi(masked(h)) = .true.

			enddo
			write(fmt, '(a,i10,a)')  '(a20,', nsnps, 'i2)'
			do p=1,ped%pedigreeSize-ped%nDummys
				write(outChrF,fmt) ped%pedigree(p)%originalId,pack(genotypes(p,:), maskedLogi)
			end do
			close(outChrF)
		enddo

		call dict%destroy()


	end subroutine readPlinkNoneBinary



	subroutine readMap(filename,dict,chroms,maxChroms, snpCounts, totalSnps,hasSexChrom)
                use HashModule
		use AlphaHouseMod

		character(len=*),intent(in) :: filename
		integer, dimension(:) ,allocatable, intent(out) :: snpCounts
		integer, intent(out) :: maxChroms
		type(DictStructure), intent(out) :: dict
		type(Chromosome),dimension(:), allocatable, intent(out) :: chroms
		integer, intent(out) :: totalSnps
		integer :: unit,i,chromCount,length, basepair
		logical :: hasSexChrom
		character(len=2) :: chrom,prevChrom
		character(len=128) :: id

		totalSnps = countLines(fileName)
		open(newunit=unit, file=filename, status='OLD')

		allocate(chroms(LARGECHROMNUMBER))
		hasSexChrom = .false.
		maxChroms = 0
		snpCounts = 0
		chromCount = 0
		do i=1,totalSnps

			read(unit, *) chrom, id,length, basepair

			if (chrom == "X" .or. chrom == 'Y') then
				hasSexChrom = .true.
			endif
			
			if (chrom == 'XY' .or. chrom == 'MT') then
				write(error_unit,*) "WARNING - No support currently for XY or MT chromosomes"
			endif
				

			if (chrom /=prevChrom) then
				chromCount = chromCount + 1

				prevChrom = chrom
				if (chromCount > maxChroms) then
					maxChroms = chromCount
				endif

			endif

			snpCounts(chromCount) = snpCounts(chromCount) + 1
			call dict%addKey(id, i)
			call chroms(chromCount)%snps%list_add(i)
		enddo

	end subroutine readMap


	subroutine readPedFile(filename,ped, maxSnps,genotypes, refAlleleOutputFile)
use PedigreeModule

		use AlphaHouseMod

		character(len=*), intent(in) :: filename
		type(pedigreeHolder), intent(out) :: ped
		integer, intent(in) :: maxSnps
		character(len=*), intent(in), optional :: refAlleleOutputFile


		character(len=IDLENGTH), dimension(:,:), allocatable :: pedArray

		character(len=1),dimension(:), allocatable :: referenceAllelePerSnps !<array saying for which snp the reference allele is
		character(len=1),dimension(:,:), allocatable :: alleles !< size nsnp x2 (for each allele,)
		integer(kind=1), dimension(:,:), allocatable,intent(out) ::  genotypes
		integer, allocatable, dimension(:) :: genderArray, phenotypeArray
		integer :: size,cursnp,i,j,stat, fileUnit,gender,phenotype
		character(len=1) :: all1, all2
		character(len=IDLENGTH) :: FAMILYID
		size = countlines(filename)

		allocate(pedArray(3,size))
		allocate(genderArray(size))
		allocate(phenotypeArray(size))
		allocate(referenceAllelePerSnps(maxSnps))
		allocate(alleles(size, maxSnps*2))



		do i=1,size
			read(fileUnit,*) familyID,pedArray(1,i),pedArray(2,i),pedArray(3,i),gender,phenotype, alleles(i,:)

			read(gender,*,iostat=stat)  genderArray(i)
			read(phenotype,*,iostat=stat)  phenotypeArray(i)
		enddo

		close(fileUnit)

		do j=1,maxSnps*2,2
			cursnp = (j/2) + 1
			referenceAllelePerSnps(cursnp) = alleles(1,j)
			do i=1,size
				all1 = alleles(i,j)
				all2 = alleles(i,j+1)
				if (all1 == '0' .or. all2 == '0') then
					genotypes(i,curSnp) = MISSINGGENOTYPECODE

				else if (all1 == all2) then

					if (all1 == referenceAllelePerSnps(curSnp) ) then
						genotypes(i,curSnp) = 2
					else
						genotypes(i,curSnp) = 0
					endif
				else !< means they are different
					genotypes(i,curSnp) = 1
				endif
			enddo
		enddo

		ped = pedigreeHolder(pedArray, genderArray)
		! ped%addGenotypeInformationFromArray(genotypes)

		if (present(refAlleleOutputFile)) then
			open(fileUnit, file=refAlleleOutputFile, status="unknown")

			do i=1,maxSnps

				write(fileUnit, '(2a5)') "snp","Ref Allele"
				write(fileUnit, '(i5,a5)') i, referenceAllelePerSnps(i)
			enddo
			close(fileUnit)
		endif
		! TODO write output map showing which snp was reference allele

	end subroutine readPedFile


end module CompatibilityModule







