module Miscellaneous

implicit none

contains


subroutine ConvertCharacterToLowerCase(LWordC)

implicit none

integer :: i,Del
character(len=2000) :: LWordC

Del = iachar('a')-iachar('A')
do i = 1, len_trim(LWordC)                                                   
    if (lge(LWordC(i:i),'A') .and. lle(LWordC(i:i),'Z')) then                  
        LWordC(i:i) = achar(iachar(LWordC(i:i)) + Del)                         
    endif
enddo


end subroutine ConvertCharacterToLowerCase

subroutine InitiateSeedFromFile(idum)

implicit none
integer :: edum,idum
DOUBLE PRECISION :: W(1),GASDEV

open (unit=3,file="Seed.txt",status="old")

!READ AND WRITE SEED BACK TO FILE
READ (3,*) idum
W(1)=GASDEV(idum)
!Code to write new seed to file
IF (idum>=0) THEN
	edum=(-1*idum)
ELSE
	edum=idum
END IF
REWIND (3)
WRITE (3,*) edum
idum=edum

end subroutine InitiateSeedFromFile


end module Miscellaneous
