
PROGRAM MANYBODYHUBBARD

  USE ATOMIC_PROPERTIES
  USE TYPES
  USE SUBINTERFACE
  USE SUBINTERFACE_LAPACK
  USE FLOQUETINITINTERFACE
  USE ARRAYS 


  IMPLICIT NONE
  TYPE(MODE),       DIMENSION(:),   ALLOCATABLE :: FIELDS
  TYPE(ATOM)                                       ID
  INTEGER,          DIMENSION(:),   ALLOCATABLE :: MODES_NUM
  INTEGER                                          TOTAL_FREQUENCIES,D_BARE_UP,D_BARE_DOWN,D_BARE
  INTEGER                                          INFO,m,INDEX0,r
  DOUBLE PRECISION, DIMENSION(:),   ALLOCATABLE :: ENERGY,E_FLOQUET,E_BARE
  COMPLEX*16,       DIMENSION(:,:), ALLOCATABLE :: H_J,H_U,U_F,H_BARE
  DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE :: P_AVG
  INTEGER         , DIMENSION(:,:), ALLOCATABLE :: states_occ,STATES_OCC_UP,STATES_OCC_DOWN
  DOUBLE PRECISION                              :: T1,T2

  INTEGER index,N_SITES,i_,N_BODIES_UP, N_BODIES_DOWN,N_BODIES_SPINS(2),D_BARE_SPINS(2),M_
  DOUBLE PRECISION t,u,t_driv,omega,D_H

  OPEN(UNIT=3,FILE="ManybodyHubbard_Fermions.dat",ACTION="WRITE")

  INFO          = 0
  N_BODIES_UP   = 2 ! PARTICLES WITH SPIN UP
  N_BODIES_DOWN = 3 ! PARTICLES WITH SPIN DOWN 
  N_SITES       = 5
  D_BARE_UP     = D_H(N_SITES,N_BODIES_UP,'F')   ! D_H EVALUATES THE NUMBER OF STATES 
  D_BARE_DOWN   = D_H(N_SITES,N_BODIES_DOWN,'F')  ! D_H EVALUATES THE NUMBER OF STATES OF DO
  
  D_BARE = D_BARE_UP*D_BARE_DOWN ! TOTAL STATES
  write(*,*) '# Number of lattice sites:         ', N_SITES
  write(*,*) '# Number of part. with spin up:    ', N_BODIES_UP
  write(*,*) '# Number of part. with spin down:  ', N_BODIES_DOWN
  write(*,*) '# Number of states spin up         ', D_BARE_UP
  write(*,*) '# Number of states spin down       ', D_BARE_down
  write(*,*) '# Number of states Fermionic states', D_BARE
  write(*,*)
  write(*,*)
  CALL FLOQUETINIT(ID,'lattice',0.1d1*D_BARE,INFO)

  ALLOCATE(E_BARE(D_BARE))             ! STORE THE ENERGY SPECTRUM
  ALLOCATE(H_BARE(D_BARE,D_BARE))      ! STORE THE BARE HAMILTONIAN
  ALLOCATE(H_J(D_BARE,D_BARE))         ! STORE THE TUNNENING MATRIX
  ALLOCATE(H_U(D_BARE,D_BARE))         ! STORES THE ONSITE INTERACTION
  ALLOCATE(MODES_NUM(2))               ! NUMBER OF DRIVING MODES
  ALLOCATE(STATES_OCC_UP(D_BARE_UP,N_SITES)) ! STORES THE STATES USING OCCUPATION NUMBER SPIN UP
  ALLOCATE(STATES_OCC_DOWN(D_BARE_DOWN,N_SITES)) ! STORES THE STATES USING OCCUPATION NUMBER SPINS DOWN
  ALLOCATE(STATES_OCC(D_BARE_UP+D_BARE_DOWN,N_SITES)) ! STORES THE STATES USING OCCUPATION NUMBER ALL SPINS

  ! CREATE THE BASIS OF STATES FOR EACH SPIN ORIENTATION
  CALL Manybody_basis(D_BARE_UP  ,N_SITES,N_BODIES_UP,  'F',STATES_OCC_UP,INFO)
  CALL Manybody_basis(D_BARE_DOWN,N_SITES,N_BODIES_DOWN,'F',STATES_OCC_DOWN,INFO)
  !CALL write_matrix_int(states_occ_UP)  
  !CALL write_matrix_int(states_occ_DOWN)
  
  D_BARE_SPINS(1) = D_BARE_UP
  D_BARE_SPINS(2) = D_BARE_DOWN
  
  N_BODIES_SPINS(1) = N_BODIES_UP
  N_BODIES_SPINS(2) = N_BODIES_DOWN
  
  STATES_OCC(1:D_BARE_UP,:)                       = STATES_OCC_UP
  STATES_OCC(D_BARE_UP+1:D_BARE_UP+D_BARE_DOWN,:) = STATES_OCC_DOWN

!  ! EVALUATE THE TUNNELING TERM OF THE HAMILTONIAN
  CALL Tunneling_F(D_BARE_SPINS,N_SITES,N_BODIES_SPINS,STATES_OCC,H_J,INFO)
  !CALL WRITE_MATRIX(ABS(H_J))
  
!  !! EVALUATE THE ON-SITE INTERACTION HAMILTONIAN
  CALL Onsite_twobody_F(D_BARE_SPINS,N_SITES,N_BODIES_SPINS,STATES_OCC,H_U,INFO)
  !CALL WRITE_MATRIX(abs(h_u))
  
  !NOW DEFINE THE DRIVING 
  MODES_NUM(1) = 1 !(STATIC FIELD)
  MODES_NUM(2) = 1 !(DRIVING BY ONE HARMONIC)
!  
  TOTAL_FREQUENCIES = SUM(MODES_NUM,1)
  ALLOCATE(FIELDS(TOTAL_FREQUENCIES))
  DO m=1,TOTAL_FREQUENCIES
     ALLOCATE(FIELDS(m)%V(D_BARE,D_BARE))
     FIELDS(m)%V = 0.0
  END DO
  
  ! HUBBARD MODEL PARAMETERS
  t      = 1.0
  u      = 0.5
  
  !DRIVING PARAMETERS
  t_driv = 0.2
  omega  = 1.0

  ! DEFINE THE TOTAL STATIC HAMILTONIAN USIING THE TUNNELING AND ON-SITE INTERACTIONS
  FIELDS(1)%V         = -t*H_J + u*H_U
  FIELDS(1)%omega     = 0
  FIELDS(1)%N_Floquet = 0
  
  ! DEFINE THE DRIVING TERM OF THE HAMILTONIAN.
  FIELDS(2)%V         = t_driv*H_J
  FIELDS(2)%omega     = omega
  FIELDS(2)%N_Floquet = 2
  
  write(*,*) '# Hubbard parameters (t,u):',t,u
  write(*,*) '# Driving parameters (t_driving,omega,N_Floquet):',t_driv,omega,FIELDS(2)%N_Floquet
  write(*,*) '# Floquet spectrum as a function of the driving frequency (first column))'


  ! EVALUATE THE SPECTRUM OF THE STATIC HAMILTONIAN
  H_BARE = FIELDS(1)%V
  CALL LAPACK_FULLEIGENVALUES(H_BARE,D_BARE,E_BARE,INFO)
  M_=32
  DO m=1,M_ ! SCAN DRIVING FREQUENCY
    FIELDS(2)%omega     = 0.1 + (m-1)*1.0/M_
    CALL MULTIMODEFLOQUETMATRIX(ID,size(modes_num,1),total_frequencies,MODES_NUM,FIELDS,INFO)
!  !CALL WRITE_MATRIX(ABS(H_FLOUET()))
!
    ALLOCATE(E_FLOQUET(SIZE(H_FLOQUET,1)))
    ALLOCATE(U_F(SIZE(H_FLOQUET,1),SIZE(H_FLOQUET,1)))
    E_FLOQUET = 0.0   
!  
    CALL LAPACK_FULLEIGENVALUES(H_FLOQUET,SIZE(H_FLOQUET,1),E_FLOQUET,INFO)
    U_F = H_FLOQUET ! FOURIER DECOMPOSITION OF THE STATES DRESSED BY MODE NUMBER 
    WRITE(3,*) FIELDS(2)%omega,E_FLOQUET
    DEALLOCATE(H_FLOQUET)
    DEALLOCATE(E_FLOQUET)
    DEALLOCATE(U_F)
    
  END DO
   
END PROGRAM MANYBODYHUBBARD

