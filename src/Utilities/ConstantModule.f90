module ConstantModule

    integer, parameter :: MissingPhaseCode = 9
    integer, parameter :: ErrorPhaseCode = -1
    integer, parameter :: MissingGenotypeCode = 3
    integer, parameter :: MissingHaplotypeCode = -99
    character, parameter :: EMPTY_PARENT = '0'
    integer, parameter :: IDLENGTH = 32
    integer, parameter :: generationThreshold = 1000
    integer, parameter :: OFFSPRINGTHRESHOLD = 150
    integer, parameter :: NOGENERATIONVALUE = -9999

end Module ConstantModule