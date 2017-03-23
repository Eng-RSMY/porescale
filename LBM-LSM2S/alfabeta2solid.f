      program twophaseflow 
c___________________________________________________
c     two-phase flow program
c___________________________________________________
c     part 1: variables declarations  
c___________________________________________________
c     velocities iv must be carefully defined!!! 
c___________________________________________________
c      include '/usr/include/fexcp.h'
!___________________________________________________
! LBM program
! Multiphase LBM, density ratio different from 1 is possible, boundary condition - bounce back
! MRT collision operator (TRT model)
! Navier-Stokes equation (collision), Stokes flow (stokes_collision)
! Interface - majority rule or interpolation
!
! Input files :
! INPUT_PARAMETERS - program parameters 
! ind              - geometry of the medium (1 - pore, 0 - solid)
! flow_data        - geometry configuration (use geometry8.1plus.f)
! init             - initial phase distribution (produced by geometry8.1plus.f)
! iteration2       - saved particle distributions (mainly used to restart the calculations)
! velocities19     - discrete velocities
!
! Output files :
! check_state_19       - run time program statistics
! color_field          - fluid color field
! Fs                   - surface tension force field
! iteration,iteration2 - particle distributions (mainly used to restart the calculations)
! laplace_check        - check laplace law information
! output.m             - program statistics (permeabilities, cappilary pressure etc)
! pressure_field       - fluid pressure field
! settings_19          - settings of the program
! blue_flux, red_flux  - red, blue fluid mean velocities
! blue_perm,red_perm   - red, blue fluid permeabilities
! ind_red_blue         - index file (1 - pure red, 6 - part red, 2 - pure blue, 7 - part blue) 
! velocity_field       - velocity field
! vel                  - mean flow velocity(seepage)
! blue..., red..., interface... - coordinates of blue, red, interface points
! blue_bmt,bubble_coordinate    - information related to bubble rising in pipe test
!___________________________________________________
! LSM program
! Input files:
! INPUT_PARAMETERS - program parameters
! ind - geometry of the medium (1 - pore, 0 - solid)
! velocities19 - discrete velocities
! Output files:
! lsm_settings - input program settings and parameters
! coord_field - coordinates of solid points
! displ_field - displacements of solid points
! velocity_field - velocities of solid points
! force_field - forces acting on solid points
!___________________________________________________
 
      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      integer*4 ncx    ! x unit cell size
      integer*4 ncy    ! y unit cell size
      integer*4 ncz    ! z unit cell size

      integer*4 nl     ! real number of the liquid points LBM
      integer*4 nps    ! dimension of the ips LBM
      integer*4 npb    ! dimension of the ipb LBM
      integer*4 npb2   ! dimension of the ipb LBM
      integer*4 npb4   ! dimension of the ipb LBM
      integer*4 npm    ! dimension of the ipm LBM

      integer*4 ns              ! number of solid points LSM
      parameter ( nthread = 1)  ! NUMBER OF THREADS LSM
      integer   nthread2        ! = nthread*2 LSM

      real*8    vv(3,19) ! discrete velocities (real numbers) LSM
      real*8    vn(3,19) ! discrete velocities normalized LSM
      real*8    vx(3,19) ! xn/|rn| LSM
      real*8    vnr(19) ! discrete velocities norms LSM
      real*8    vni(19) ! discrete velocities norms inverse LSM

      integer   iv(3,19) ! discrete velocities (integer numbers)
      integer   niv(19) ! indices of the opposite velocities

      integer   ib(3,9) ! bond vectors (9 instead of 18 for uniqueness) LSM
      real*8    vb(3,9) ! bond vectors (real numbers) LSM
      real*8    vbn(9) ! norms LSM
      real*8    vbi(9) ! norms inverse LSM
      real*8    bn(3,9) ! normalized vectors LSM
      real*8    bx(3,9) ! xn/|rn| LSM

      real*8 rs ! solid body density LSM
      real*8 rsi ! inverse of solid body density LSM
      real*8 alf1 ! alpha linear spring constant
      real*8 bet1 ! beta angular spring constant
      real*8 alf2 ! alpha 2
      real*8 bet2 !beta 2
      real*8 Em1 ! Young modulus1
      real*8 nu1 ! Poisson's ratio 1
      real*8 Em2 !Young 2
      real*8 nu2 ! Poisson 2
      integer*4 itm ! simulation duration
      integer*4 its ! save parameter
     

      integer*4, dimension(:,:), allocatable :: bon ! bonds LSM
      integer*4, dimension(:,:), allocatable :: ang ! angles LSM

      integer*4, dimension(:,:), allocatable :: icors ! coordinates of the solid points LSM
      integer*4, dimension(:,:,:), allocatable :: mijks ! point numbers LSM

      real*8, dimension(:,:), allocatable :: adat ! elastic solid points acceleration LSM
      real*8, dimension(:,:), allocatable :: vdat ! elastic solid points velocity LSM
      real*8, dimension(:,:), allocatable :: rdat ! elastic solid points displacements LSM

      integer, dimension(:,:,:), allocatable :: ind  ! porous medium structure
      integer, dimension(:,:,:), allocatable :: inda ! all solid points indicator matrix
      integer, dimension(:,:,:), allocatable :: inds ! solid point indicator matrix
      integer, dimension(:), allocatable :: ipcx ! x-axis periodic boundary conditions
      integer, dimension(:), allocatable :: ipcy ! y-axis periodic boundary conditions
      integer, dimension(:), allocatable :: ipcz ! z-axis periodic boundary conditions
      integer, dimension(:), allocatable :: iicx ! x-axis periodic boundary conditions
      integer, dimension(:), allocatable :: iicy ! y-axis periodic boundary conditions
      integer, dimension(:), allocatable :: iicz ! z-axis periodic boundary conditions
	real*8, dimension(:), allocatable :: sbond ! linear bond constants
      real*8, dimension(:), allocatable :: sbond1 ! linear bond constants
      real*8, dimension(:), allocatable :: sbond2 ! linear bond constants
      real*8, dimension(:), allocatable :: sbondin ! linear bond constants
      real*8, dimension(:), allocatable :: abond ! angular bond constants
      real*8, dimension(:), allocatable :: abond1 ! angular bond constants
      real*8, dimension(:), allocatable :: abond2 ! angular bond constants
      real*8, dimension(:), allocatable :: abondin ! angular bond constants in cube


      integer*4, dimension(:,:),   allocatable :: icor ! coordinates of the liquid points
      integer*4, dimension(:,:,:), allocatable :: mijk ! point numbers
      integer*4, dimension(:,:),   allocatable :: ips  ! simple propagation table
      integer*4, dimension(:,:),   allocatable :: ipb   ! bounce-back propagation table
      integer*4, dimension(:,:),   allocatable :: ipb2  ! bounce-back propagation table
      integer*4, dimension(:,:),   allocatable :: ipb4  ! bounce-back propagation table
c      integer*4, dimension(:,:),   allocatable :: ipm  ! multireflection propagation table
      integer*4, dimension(:,:),   allocatable :: intf ! red-blue fluid interface  

      real*8, dimension(:,:),      allocatable :: fr   ! red particle populations
      real*8, dimension(:,:),      allocatable :: fb   ! blue particle populations
      real*8, dimension(:,:),      allocatable :: pcfr ! red post collision particle populations
      real*8, dimension(:,:),      allocatable :: pcfb ! blue post collision particle populations
      real*8, dimension(:),        allocatable :: ipmq ! solid wall distance parameters for MR 

      real*8, dimension(:),        allocatable :: cf   ! color field
      real*8, dimension(:),        allocatable :: rr   ! red fluid density field
      real*8, dimension(:),        allocatable :: rb   ! blue fluid density field

      real*8 bfr(3)     ! red fluid body force
      real*8 bfb(3)     ! blue fluid body force
      real*8 bfi(3)     ! body force at interface
      real*8 Sr(19)     ! red collision vector
      real*8 Sb(19)     ! blue collision vector
      real*8 Si(19)     ! fluid-fluid interface collision vector
      real*8 vir        ! red fluid viscosity
      real*8 vib        ! blue fluid viscosity
      real*8 vi         ! interface fluid viscosity
      real*8 lsize      ! linear size
      real*8 t0         ! unit cell volume
      real*8 cb2        ! blue fluid sound speed power 2
      real*8 ci2        ! interface sound speed power 2
      real*8 tr1,tr2,tr3,tb1,tb2,tb3 ! lattice weights
      real*8 tr(19)     ! red fluid lattice weigth coefficients
      real*8 tb(19)     ! blue fluid lattice weigth coefficients
      integer itms      ! outer loop start indices
      integer*4 lp1(3),lp2(3),lp3(3),lp4(3)
c___________________________________________________
c     program parameters
c___________________________________________________
      real*8 cr2,rr0,rb0,B,sig,svr,svb,wet,eps,ee ! see file INPUT_PARAMETERS
      integer idir,itw,mtype        ! see file INPUT_PARAMETERS
      integer iipore ! pore filled with fluid
      integer npores ! number of distinct pores

c      parameter(cr2   = 1.D0/3.D0)  ! red fluid sound speed power 2
c      parameter(rr0   = 1.D0)       ! initial red fluid density (in rest)
c      parameter(rb0   = 1.D0)       ! initial blue fluid density (in rest)
c      parameter(B     = 1.D0)       ! regulate interface width
c      parameter(sigp  = 0.00002D0)  ! regulate surface tension
c      parameter(svr   = 1.D0)       ! viscosity related red fluid relaxation eigen value
c      parameter(svb   = 1.D0)       ! viscosity related blue fluid relaxation eigen value
c      parameter(wet   = 0.5D0)      ! wettability (-1,1) (>0 - red fluid wettable)

c      parameter(idir  = 1)          ! direction of the body force (1 - x direction)
c      parameter(itm   = 10)         ! main loop number of steps
c      parameter(itw   = 100)        ! intermediate loop (save data after each itw iterations)
c      parameter(eps   = -0.000001d0)! parameter for permeability convergence test
c      parameter(mtype = 0)          ! 1 - Ai is used at interface, 0 - the majority rule is used
c      parameter(icon  = 0)          ! read initial state data from archiv ? (1 - yes, 0 - no)
c      parameter(ee    = 0.D0)       ! small number to supress small distributions (min = 0.D0)
c___________________________________________________
c     technical variables
c___________________________________________________      
      integer checkstat               ! check the success of allocate command
      real*8 ri                       ! fluid density at interface 
      real*8 u(3)                     ! liquid point velocity
      real*8 f(19)                    ! distribution function at interface
      real*8 pcf(19)                  ! postcollision distribution function at interface
      real*8 q1,q2,q                  ! coefficients for multireflection
      real*8 svi                      ! relaxation matrix viscosity related eigen value
      real*8 sat                      ! blue fluid saturation
      character*8  date               ! current date
      character*10 time               ! current time
      character*30 format211          ! format for pgf95

      real*8 c1d6,c1d12,c5d399,c19d399
      real*8 c11d2394,c1d63,c1d18,c1d36
      real*8 c4d1197,c1d252,c1d72,c1d24
! LSM_START
      integer*4 nx,ny,nz ! variables for point coordinates
      integer*4 iz(1:3) ! technical variable for comparation
      integer*4 npc(1:3)  ! coordinates of adjacent point
      integer*4 npc1(1:3) ! coordinates of adjacent point
      integer*4 npc2(1:3) ! coordinates of adjacent point
      integer*4 npc3(1:3) ! coordinates of adjacent point
      real*8 xn(3),xr(3),rn(3),rt(3) ! vectors in linear spring force calculation
      real*8 anf(9,48) ! angle plane normal, angular force vectors j k; for angular springs
      real*8 c1ds2,c1ds3,c1ds6,cs2d3 ! numerical constants
      real*8 c1d2,c1d2s3
      real*8 RM(3,3) ! rotation matrix
      real*8 w ! frequency
      integer*8 nbo,nna ! bonds counter
      integer nta(2,48) ! angles table, angles numeration is the same as in anf
      integer*4 npj(3),npk(3),npl(3) ! angles counter, angleside endpoints coordinates
      real*8 flin(3) ! linear spring force
      real*8 dfi ! delta phi, angle change for angular force
      real*8 xnj(3),xrj(3),rnj(3),rtj(3),xnk(3),xrk(3),rnk(3),rtk(3) ! force calculation vectors
      real*8 RTO(3),VTO(3),FTO(3)
      real*8 sigm(3,3),sigmt(3,3)
      real*8 FX(3),FY(3),FZ(3),FXJ(3),FXK(3)
      real*8 F20(1:3,20)
      real*8 F20Y(1:3,20)
      real*8 F20Z(1:3,20)
      real*8 scr(3),scrj(3),scrk(3)
      integer*4 jv(3),kv(3),ip0(3),mp(3)

      integer, dimension(:), allocatable :: layers
      integer*8, dimension(:), allocatable :: layb
      integer*8, dimension(:), allocatable :: lib
      integer*8, dimension(:), allocatable :: lia

      real*8 sumloc(3)
	integer icon
! LSM_END 
c___________________________________________________
c     part 2: variable initialization
c___________________________________________________
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'start = ',time
! LSM_START
      nthread2=2*nthread

      c1ds2=1.d0/sqrt(2.d0) ! some numerical constants
      c1ds3=1.d0/sqrt(3.d0)
      c1ds6=1.d0/sqrt(6.d0)
      cs2d3=sqrt(2.d0/3.d0)
      c1d2=1.d0/2.d0
      c1d2s3=1.d0/(2.d0*sqrt(3.d0))
! 1:3 plane normal n, 4:6 fj, 7:9 fk
! xy plane
      anf(1:9,1)=(/0.d0,0.d0,1.d0,0.d0,1.d0,0.d0
     &                           ,c1d2,-c1d2,0.d0/) ! 2 8
      anf(1:9,2)=(/0.d0,0.d0,1.d0,-c1d2,c1d2,0.d0
     &                           ,1.d0,0.d0,0.d0/) ! 8 4
      anf(1:9,3)=(/0.d0,0.d0,1.d0,-1.d0,0.d0,0.d0
     &                           ,c1d2,c1d2,0.d0/) ! 4 9
      anf(1:9,4)=(/0.d0,0.d0,1.d0,-c1d2,-c1d2,0.d0
     &                           ,0.d0,1.d0,0.d0/) ! 9 3
      anf(1:9,5)=(/0.d0,0.d0,1.d0,0.d0,-1.d0,0.d0
     &                           ,-c1d2,c1d2,0.d0/) ! 3 11
      anf(1:9,6)=(/0.d0,0.d0,1.d0,c1d2,-c1d2,0.d0
     &                           ,-1.d0,0.d0,0.d0/) ! 11 5
      anf(1:9,7)=(/0.d0,0.d0,1.d0,1.d0,0.d0,0.d0
     &                           ,-c1d2,-c1d2,0.d0/) ! 5 10
      anf(1:9,8)=(/0.d0,0.d0,1.d0,c1d2,c1d2,0.d0
     &                           ,0.d0,-1.d0,0.d0/) ! 10 2
! xz plane
      anf(1:9,9)=(/0.d0,1.d0,0.d0,0.d0,0.d0,-1.d0
     &                           ,-c1d2,0.d0,c1d2/) ! 2 12
      anf(1:9,10)=(/0.d0,1.d0,0.d0,c1d2,0.d0,-c1d2
     &                           ,-1.d0,0.d0,0.d0/) ! 12 6
      anf(1:9,11)=(/0.d0,1.d0,0.d0,1.d0,0.d0,0.d0
     &                           ,-c1d2,0.d0,-c1d2/) ! 6 13
      anf(1:9,12)=(/0.d0,1.d0,0.d0,c1d2,0.d0,c1d2
     &                           ,0.d0,0.d0,-1.d0/) ! 13 3
      anf(1:9,13)=(/0.d0,1.d0,0.d0,0.d0,0.d0,1.d0
     &                           ,c1d2,0.d0,-c1d2/) ! 3 15
      anf(1:9,14)=(/0.d0,1.d0,0.d0,-c1d2,0.d0,c1d2
     &                           ,1.d0,0.d0,0.d0/) ! 15 7
      anf(1:9,15)=(/0.d0,1.d0,0.d0,-1.d0,0.d0,0.d0
     &                           ,c1d2,0.d0,c1d2/) ! 7 14
      anf(1:9,16)=(/0.d0,1.d0,0.d0,-c1d2,0.d0,-c1d2
     &                           ,0.d0,0.d0,1.d0/) ! 14 2
! yz plane
      anf(1:9,17)=(/1.d0,0.d0,0.d0,0.d0,0.d0,1.d0
     &                           ,0.d0,c1d2,-c1d2/) ! 4 16
      anf(1:9,18)=(/1.d0,0.d0,0.d0,0.d0,-c1d2,c1d2
     &                           ,0.d0,1.d0,0.d0/) ! 16 6
      anf(1:9,19)=(/1.d0,0.d0,0.d0,0.d0,-1.d0,0.d0
     &                           ,0.d0,c1d2,c1d2/) ! 6 17
      anf(1:9,20)=(/1.d0,0.d0,0.d0,0.d0,-c1d2,-c1d2
     &                           ,0.d0,0.d0,1.d0/) ! 17 5
      anf(1:9,21)=(/1.d0,0.d0,0.d0,0.d0,0.d0,-1.d0
     &                           ,0.d0,-c1d2,c1d2/) ! 5 19
      anf(1:9,22)=(/1.d0,0.d0,0.d0,0.d0,c1d2,-c1d2
     &                           ,0.d0,-1.d0,0.d0/) ! 19 7
      anf(1:9,23)=(/1.d0,0.d0,0.d0,0.d0,1.d0,0.d0
     &                           ,0.d0,-c1d2,-c1d2/) ! 7 18
      anf(1:9,24)=(/1.d0,0.d0,0.d0,0.d0,c1d2,c1d2
     &                           ,0.d0,0.d0,-1.d0/) ! 18 4
! xy1
      anf(1:9,25)=(/-c1ds3,-c1ds3,c1ds3,-c1d2s3,c1ds3,c1d2s3
     &                           ,c1ds3,-c1d2s3,c1d2s3/) ! 12 16
      anf(1:9,26)=(/c1ds3,-c1ds3,c1ds3,-c1ds3,-c1d2s3,c1d2s3
     &                           ,c1d2s3,c1ds3,c1d2s3/) ! 16 13
      anf(1:9,27)=(/c1ds3,c1ds3,c1ds3,c1d2s3,-c1ds3,c1d2s3
     &                           ,-c1ds3,c1d2s3,c1d2s3/) ! 13 17
      anf(1:9,28)=(/-c1ds3,c1ds3,c1ds3,c1ds3,c1d2s3,c1d2s3
     &                           ,-c1d2s3,-c1ds3,c1d2s3/) ! 17 12
! xy-1
      anf(1:9,29)=(/c1ds3,c1ds3,c1ds3,-c1d2s3,c1ds3,-c1d2s3
     &                           ,c1ds3,-c1d2s3,-c1d2s3/) ! 14 18
      anf(1:9,30)=(/-c1ds3,c1ds3,c1ds3,-c1ds3,-c1d2s3,-c1d2s3
     &                           ,c1d2s3,c1ds3,-c1d2s3/) ! 18 15
      anf(1:9,31)=(/-c1ds3,-c1ds3,c1ds3,c1d2s3,-c1ds3,-c1d2s3
     &                           ,-c1ds3,c1d2s3,-c1d2s3/) ! 15 19
      anf(1:9,32)=(/c1ds3,-c1ds3,c1ds3,c1ds3,c1d2s3,-c1d2s3
     &                           ,-c1d2s3,-c1ds3,-c1d2s3/) ! 19 14
! yz1
      anf(1:9,33)=(/c1ds3,-c1ds3,-c1ds3,c1d2s3,-c1d2s3,c1ds3
     &                           ,c1d2s3,c1ds3,-c1d2s3/) ! 8 12
      anf(1:9,34)=(/c1ds3,c1ds3,-c1ds3,c1d2s3,-c1ds3,-c1d2s3
     &                           ,c1d2s3,c1d2s3,c1ds3/) ! 12 10
      anf(1:9,35)=(/c1ds3,c1ds3,c1ds3,c1d2s3,c1d2s3,-c1ds3
     &                           ,c1d2s3,-c1ds3,c1d2s3/) ! 10 14
      anf(1:9,36)=(/c1ds3,-c1ds3,c1ds3,c1d2s3,c1ds3,c1d2s3
     &                           ,c1d2s3,-c1d2s3,-c1ds3/) ! 14 8
! yz-1
      anf(1:9,37)=(/c1ds3,c1ds3,c1ds3,-c1d2s3,-c1d2s3,c1ds3
     &                           ,-c1d2s3,c1ds3,-c1d2s3/) ! 9 13
      anf(1:9,38)=(/c1ds3,-c1ds3,c1ds3,-c1d2s3,-c1ds3,-c1d2s3
     &                           ,-c1d2s3,c1d2s3,c1ds3/) ! 13 11
      anf(1:9,39)=(/c1ds3,-c1ds3,-c1ds3,-c1d2s3,c1d2s3,-c1ds3
     &                           ,-c1d2s3,-c1ds3,c1d2s3/) ! 11 15
      anf(1:9,40)=(/c1ds3,c1ds3,-c1ds3,-c1d2s3,c1ds3,c1d2s3
     &                           ,-c1d2s3,-c1d2s3,-c1ds3/) ! 15 9
! xz1
      anf(1:9,41)=(/c1ds3,-c1ds3,c1ds3,-c1d2s3,c1d2s3,c1ds3
     &                           ,c1ds3,c1d2s3,-c1d2s3/) ! 8 16
      anf(1:9,42)=(/-c1ds3,-c1ds3,c1ds3,-c1ds3,c1d2s3,-c1d2s3
     &                           ,c1d2s3,c1d2s3,c1ds3/) ! 16 9
      anf(1:9,43)=(/-c1ds3,-c1ds3,-c1ds3,c1d2s3,c1d2s3,-c1ds3
     &                           ,-c1ds3,c1d2s3,c1d2s3/) ! 9 18
      anf(1:9,44)=(/c1ds3,-c1ds3,-c1ds3,c1ds3,c1d2s3,c1d2s3
     &                           ,-c1d2s3,c1d2s3,-c1ds3/) ! 18 8
! xz-1
      anf(1:9,45)=(/-c1ds3,-c1ds3,-c1ds3,-c1d2s3,-c1d2s3,c1ds3
     &                           ,c1ds3,-c1d2s3,-c1d2s3/) ! 10 17
      anf(1:9,46)=(/c1ds3,-c1ds3,-c1ds3,-c1ds3,-c1d2s3,-c1d2s3
     &                           ,c1d2s3,-c1d2s3,c1ds3/) ! 17 11
      anf(1:9,47)=(/c1ds3,-c1ds3,c1ds3,c1d2s3,-c1d2s3,-c1ds3
     &                           ,-c1ds3,-c1d2s3,c1d2s3/) ! 11 19
      anf(1:9,48)=(/-c1ds3,-c1ds3,c1ds3,c1ds3,-c1d2s3,c1d2s3
     &                           ,-c1d2s3,-c1d2s3,-c1ds3/) ! 19 10

! pi/4 angles clock counterwise
! xy plane
      nta(1:2,1)=(/2,8/) ! xy
      nta(1:2,2)=(/8,4/) ! xy
      nta(1:2,3)=(/4,9/) ! xy
      nta(1:2,4)=(/9,3/) ! xy
      nta(1:2,5)=(/3,11/) ! xy
      nta(1:2,6)=(/11,5/) ! xy
      nta(1:2,7)=(/5,10/) ! xy
      nta(1:2,8)=(/10,2/) ! xy
! xz plane
      nta(1:2,9)=(/2,12/) ! xz
      nta(1:2,10)=(/12,6/) ! xz
      nta(1:2,11)=(/6,13/) ! xz
      nta(1:2,12)=(/13,3/) ! xz
      nta(1:2,13)=(/3,15/) ! xz
      nta(1:2,14)=(/15,7/) ! xz
      nta(1:2,15)=(/7,14/) ! xz
      nta(1:2,16)=(/14,2/) ! xz
! yz plane
      nta(1:2,17)=(/4,16/) ! yz
      nta(1:2,18)=(/16,6/) ! yz
      nta(1:2,19)=(/6,17/) ! yz
      nta(1:2,20)=(/17,5/) ! yz
      nta(1:2,21)=(/5,19/) ! yz
      nta(1:2,22)=(/19,7/) ! yz
      nta(1:2,23)=(/7,18/) ! yz
      nta(1:2,24)=(/18,4/) ! yz
! pi/3 angles
! comments - sides
      nta(1:2,25)=(/12,16/) ! xy1
      nta(1:2,26)=(/16,13/) ! xy1
      nta(1:2,27)=(/13,17/) ! xy1
      nta(1:2,28)=(/17,12/) ! xy1
      nta(1:2,29)=(/14,18/) ! xy-1
      nta(1:2,30)=(/18,15/) ! xy-1
      nta(1:2,31)=(/15,19/) ! xy-1
      nta(1:2,32)=(/19,14/) ! xy-1

      nta(1:2,33)=(/8,12/) ! yz1
      nta(1:2,34)=(/12,10/) ! yz1
      nta(1:2,35)=(/10,14/) ! yz1
      nta(1:2,36)=(/14,8/) ! yz1
      nta(1:2,37)=(/9,13/) ! yz-1
      nta(1:2,38)=(/13,11/) ! yz-1
      nta(1:2,39)=(/11,15/) ! yz-1
      nta(1:2,40)=(/15,9/) ! yz-1

      nta(1:2,41)=(/8,16/) ! xz1
      nta(1:2,42)=(/16,9/) ! xz1
      nta(1:2,43)=(/9,18/) ! xz1
      nta(1:2,44)=(/18,8/) ! xz1
      nta(1:2,45)=(/10,17/) ! xz-1
      nta(1:2,46)=(/17,11/) ! xz-1
      nta(1:2,47)=(/11,19/) ! xz-1
      nta(1:2,48)=(/19,10/) ! xz-1
! LSM_END

      open(1,file='INPUT_PARAMETERS')
      read(1,*)cr2            ! red fluid sound speed power 2
      read(1,*)rr0            ! pure red fluid density
      read(1,*)rb0            ! pure blue fluid density
      read(1,*)B              ! interface width parameter (MIN = 0 MAX = 1)
      read(1,*)sig            ! surface tension coefficient
      read(1,*)vir            ! red fluid cinematic viscosity
      read(1,*)vib            ! blue fluid cinematic viscosity
      read(1,*)wet            ! wettability (-1,1) (>0 - red fluid wettable)
      read(1,*)idir           ! direction of the body force (1 - x direction)
      read(1,*)itm            ! main loop number of steps
      read(1,*)itw            ! intermediate loop numer of steps
      read(1,*)its            ! save parameter
      read(1,*)eps            ! parameter for permeability convergence test
      read(1,*)mtype          ! 1 - interpolation at interface, 0 - majority rule
      read(1,*)icon           ! read initial state data from archiv ? (1 - yes, 0 - no)
      read(1,*)sat            ! blue fluid saturation (used only in intialization)
      read(1,*)iipore         ! pore filled with fluid
      read(1,*)npores         ! number of distinct pores
      read(1,*)ee             ! small number to supress small distributions (min = 0.D0)
      read(1,*)lsize          ! linear size for Reynolds number
      read(1,*)(bfr(i),i=1,3) ! red fluid body force
      read(1,*)(bfb(i),i=1,3) ! blue fluid body force
! LSM code start
      read(1,*)ncx ! x unit cell size
      read(1,*)ncy ! y unit cell size
      read(1,*)ncz ! z unit cell size
      read(1,*)Em1 ! Young modulus
      read(1,*)nu1 ! Poisson's ratio
	read(1,*)Em2 ! Young modulus of 2nd solid
      read(1,*)nu2 ! Poisson's ratio of 2nd solid
      read(1,*)rs ! solid medium density
      read(1,*)dt ! integration time step
      read(1,*)dl ! lattice unit step (distance between two lattice nodes)
! LSM code end
      close(1)
! LSM code start

	allocate(layers(2*nthread),stat=checkstat) ! create medium structure array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ind'
       stop
      endif

      allocate(layb(2*nthread+1),stat=checkstat) ! create medium structure array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ind'
       stop
      endif

      allocate(lib(2*nthread+1),stat=checkstat) ! create medium structure array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ind'
       stop
      endif

      allocate(lia(2*nthread+1),stat=checkstat) ! create medium structure array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ind'
       stop
      endif

      alf1=dl*Em1/(5.d0-10.d0*nu1) ! linear spring constant
      bet1=dl*dl*dl*Em1*(4*nu1-1)/(20.d0*(2*nu1*nu1+nu1-1)) ! angular spring constant
      alf2=dl*Em2/(5.d0-10.d0*nu2) ! linear spring constant
      bet2=dl*dl*dl*Em2*(4*nu2-1)/(20.d0*(2*nu2*nu2+nu2-1)) ! angular spring constant
      rsi=1.d0/rs


      open(11,file='velocities9') ! read bond vectors
      do i=1,3
       read(11,129) (ib(i,j),j=1,9) ! read bond vectors from the file
      enddo
      vb = ib ! real numbers version of bond vectors
129   format(9i3)

      open(11,file='velocities19') ! read discrete velocities
      do i=1,3
       read(11,119) (iv(i,j),j=1,19) ! read discrete velocities from the file
      enddo
      vv = iv ! real numbers version of discrete velocities
119   format(19i3)

      niv=(/(0,i=1,19)/) ! initialize niv
      do i=1,19 ! define opposite velocities numbers
        do j=1,19
         iz(1:3)=iv(1:3,i)+iv(1:3,j)
         if(iz(1).eq.0.and.iz(2).eq.0.and.iz(3).eq.0) then
          niv(i)=j
         endif
        enddo
      enddo
      close(11)

      allocate(ind(ncx,ncy,ncz),stat=checkstat) ! create medium structure array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ind'
       stop
      endif

      open(12,file='ind') ! open medium structure index file (1-pore, 0-solid)
      write(format211,*)'(" ",',ncx,'i1)' ! create format to read from 'ind'
      do k=1,ncz
       do j=1,ncy
        read(12,fmt=format211)(ind(i,j,k),i=1,ncx) ! read structure data from the file
       enddo
      enddo
      close(12)

c      do k=1,ncz
c       do j=1,ncy
c        do i=1,ncx
c         if(ind(i,j,k).gt.1)then ! make all pores ind = 1
c          ind(i,j,k)=1
c         endif
c        enddo
c       enddo 
c      enddo

      allocate(inda(ncx+1,ncy+1,ncz+1),stat=checkstat) ! create solid point indicator matrix
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for inda'
       stop
      endif

      inda=1     ! initialize with pores
      do k=1,ncz
       do j=1,ncy
        do i=1,ncx
         if(ind(i,j,k).eq.0.or.ind(i,j,k).eq.3)then ! solid element is detected
          inda(i,j,k)=0
          inda(i+1,j,k)=0
          inda(i,j+1,k)=0
          inda(i,j,k+1)=0
          inda(i+1,j+1,k)=0
          inda(i+1,j,k+1)=0
          inda(i,j+1,k+1)=0
          inda(i+1,j+1,k+1)=0
         endif
        enddo
       enddo
      enddo

      allocate(inds(ncx,ncy,ncz),stat=checkstat) ! create solid point indicator matrix
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for inds'
       stop
      endif

      do j=1,ncy+1
       do k=1,ncz+1
        inda(1,j,k)=min(inda(1,j,k),inda(ncx+1,j,k)) ! stick together x sides
       enddo
      enddo

      do i=1,ncx+1
       do k=1,ncz+1
        inda(i,1,k)=min(inda(i,1,k),inda(i,ncy+1,k)) ! stick together y sides
       enddo
      enddo

      do i=1,ncx+1
       do j=1,ncy+1
        inda(i,j,1)=min(inda(i,j,1),inda(i,j,ncz+1)) ! stick together z sides
       enddo
      enddo

      inds=1 ! initialize with pores
      inds(1:ncx,1:ncy,1:ncz)=inda(1:ncx,1:ncy,1:ncz) ! initialize from inda

      deallocate(inda) ! dont need it
      ncx=ncx ! new bounds of the domain
      ncy=ncy
      ncz=ncz

!!! Each layer must contain solid points
      layers = INT(ncz/(nthread2)) ! initial layers width (2*number of threads)
      do i=1,mod(ncz,nthread2)     ! adjust width by reminder redistribution
       layers(i)=layers(i)+1
      enddo

      ns      = 0 ! initialize number of solid points
      kend    = 0
      layb(1) = 0
      do l=1,nthread2 ! loop over the layers
       kstart = kend+1
       kend   = kstart+layers(l)-1
! ATTENTION ! here must be the same order for k-j-i as in the loop where ICORS defined
       do k=kstart,kend ! count the number of solid points
        do j=1,ncy
         do i=1,ncx
          if(inds(i,j,k).eq.0) then ! 1 - liquid or pore point, 0 - solid point
           ns = ns + 1
          endif
         enddo
        enddo
       enddo
       layb(l+1)=ns
      enddo
      rns=ns

      allocate(icors(3,ns),stat=checkstat) ! create icors (solid points coordinates)
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for icors'
       stop
      endif

      allocate(mijks(ncx,ncy,ncz),stat=checkstat) ! create mijks (solid points numbers)
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for mijk'
       stop
      endif

      mijks = 0 ! initialize mijks (0 - pore, not zero - solid)
      ns = 0 ! initialize number of solid points
      do k=1,ncz ! define coordinates and numbers of solid points
       do j=1,ncy
        do i=1,ncx
         if(inds(i,j,k).eq.0) then ! 0 - solid point
          ns = ns + 1
! to take into account dl icors should be changed
          icors(1,ns) = i ! define coordinate of the solid point
          icors(2,ns) = j
          icors(3,ns) = k
          mijks(i,j,k) = ns ! assign the number to the solid point
         endif
        enddo
       enddo
      enddo

      allocate(ipcx(ncx+2),stat=checkstat) ! create x-axis periodic boundary conditions
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ipcx'
       stop
      endif

      allocate(ipcy(ncy+2),stat=checkstat) ! create y-axis periodic boundary conditions
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ipcy'
       stop
      endif

      allocate(ipcz(ncz+2),stat=checkstat) ! create z-axis periodic boundary conditions
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ipcz'
       stop
      endif

      allocate(iicx(ncx+2),stat=checkstat) ! create x-axis periodic boundary conditions
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for iicx'
       stop
      endif
      allocate(iicy(ncy+2),stat=checkstat) ! create y-axis periodic boundary conditions
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for iicy'
       stop
      endif
      allocate(iicz(ncz+2),stat=checkstat) ! create z-axis periodic boundary conditions
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for iicz'
       stop
      endif

      iicx=(/ncx,(i,i=1,ncx),1/) ! s.p. bound.cond. ncx+1 - max, ncx+2 - imposible !
      iicy=(/ncy,(i,i=1,ncy),1/)
      iicz=(/ncz,(i,i=1,ncz),1/)

      ipcx=(/ncx,(i,i=1,ncx),1/) ! periodic boundary conditions vectors
      ipcy=(/ncy,(i,i=1,ncy),1/)
      ipcz=(/ncz,(i,i=1,ncz),1/)

      nbo = 0 ! initialize the number of bonds counter
      do i=1,ns ! solid points loop
       do j=1,9 ! bond vectors loop (velocities9 file)
        npc(1:3)=icors(1:3,i)+ib(1:3,j) ! coordinates of the point adjacent to i by bond j
        nx1=icors(1,i)
        ny1=icors(2,i)
        nz1=icors(3,i)
        nx=ipcx(npc(1)+1) ! apply periodic conditions
        ny=ipcy(npc(2)+1) ! apply periodic conditions
        nz=ipcz(npc(3)+1) ! apply periodic conditions
        if(inds(nx,ny,nz).eq.0) then ! the next point is solid (may be there is a bond)
         nx1=iicx(nx1+1) ! s.p. for F1-Fn=E
         ncube1=0
         ncube2=0
         if(j.le.3)then ! first three cases
          if(j.eq.1)then ! 1 0 0 bond
c           ncube=ind(nx1,ny1,nz1)+ind(nx1,ny1,iicz(nz1))
c     &     +ind(nx1,iicy(ny1),nz1)+ind(nx1,iicy(ny1),iicz(nz1))
              if (ind(nx1,ny1,nz1).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then 
                                              ncube2=ncube2+1
              endif    
              if (ind(nx1,iicy(ny1),nz1).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),iicz(nz1)).eq.0) then 
                                                     ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),iicz(nz1)).eq.3) then
                                                      ncube2=ncube2+1
              endif
          elseif(j.eq.2)then ! 0 1 0 bo
c           ncube=ind(nx1,ny1,nz1)+ind(iicx(nx1),ny1,nz1)
c     &     +ind(nx1,ny1,iicz(nz1))+ind(iicx(nx1),ny1,iicz(nz1))
              if (ind(nx1,ny1,nz1).eq.0) then
                                            ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                            ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,nz1).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,nz1).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then 
                                             ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,iicz(nz1)).eq.0) then 
                                                     ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,iicz(nz1)).eq.3) then 
                                                      ncube2=ncube2+1
              endif

               
          elseif(j.eq.3)then ! 0 0 1 bond
c           ncube=ind(nx1,ny1,nz1)+ind(iicx(nx1),ny1,nz1)
c     &     +ind(nx1,iicy(ny1),nz1)+ind(iicx(nx1),iicy(ny1),nz1)
              if (ind(nx1,ny1,nz1).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                             ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,nz1).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,nz1).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),nz1).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),iicy(ny1),nz1).eq.0) then 
                                                     ncube1=ncube1+1
              elseif (ind(iicx(nx1),iicy(ny1),nz1).eq.3) then 
                                                      ncube2=ncube2+1
              endif
           endif
          ncube=0
          ncube=ncube1+ncube2
          if(ncube.gt.0)then
           nbo=nbo+1 ! there is a bond
          endif
         else ! last six cases
          if(j.eq.4)then ! 1 1 0
c           ncube=ind(nx1,ny1,nz1)+ind(nx1,ny1,iicz(nz1))
              if (ind(nx1,ny1,nz1).eq.0) then
                                               ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                               ncube2=ncube2+1
              endif
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then 
                                               ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then
                                               ncube2=ncube2+1
              endif
          elseif(j.eq.5)then ! 1 -1 0
c           ncube=ind(nx1,iicy(ny1),nz1)+ind(nx1,iicy(ny1),iicz(nz1))
         
              if (ind(nx1,iicy(ny1),nz1).eq.0) then 
                                               ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then
                                               ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),iicz(nz1)).eq.0) then 
                                                         ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),iicz(nz1)).eq.3) then 
                                                         ncube2=ncube2+1
              endif

          elseif(j.eq.6)then ! 1 0 1
c           ncube=ind(nx1,ny1,nz1)+ind(nx1,iicy(ny1),nz1)
              if (ind(nx1,ny1,nz1).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),nz1).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then 
                                              ncube2=ncube2+1
              endif
 
          elseif(j.eq.7)then ! 1 0 -1
c           ncube=ind(nx1,ny1,iicz(nz1))+ind(nx1,iicy(ny1),iicz(nz1))
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),iicz(nz1)).eq.0) then
                                                         ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),iicz(nz1)).eq.3) then 
                                                         ncube2=ncube2+1
              endif
     
          elseif(j.eq.8)then ! 0 1 1
c           ncube=ind(nx1,ny1,nz1)+ind(iicx(nx1),ny1,nz1)
              if (ind(nx1,ny1,nz1).eq.0) then 
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,nz1).eq.0) then 
                                                         ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,nz1).eq.3) then 
                                                         ncube2=ncube2+1
              endif
          
          elseif(j.eq.9)then ! 0 1 -1
c           ncube=ind(nx1,ny1,iicz(nz1))+ind(iicx(nx1),ny1,iicz(nz1))
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then 
                                              ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,iicz(nz1)).eq.0) then 
                                                         ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,iicz(nz1)).eq.3) then 
                                                         ncube2=ncube2+1
              endif
          endif
          ncube=ncube1+ncube2
          if(ncube.gt.0)then
           nbo=nbo+1 ! there is a bond
          endif
         endif
        endif
       enddo
      enddo

      allocate(bon(3,nbo),stat=checkstat) ! create bon - bonds array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for bon'
       stop
      endif

      allocate(sbond(nbo),stat=checkstat) ! create sbond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sbond'
       stop
      endif
      allocate(sbond1(nbo),stat=checkstat) ! create sbond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sbond'
       stop
      endif
      allocate(sbond2(nbo),stat=checkstat) ! create sbond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sbond'
       stop
      endif
      allocate(sbondin(nbo),stat=checkstat) ! create sbond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sbond'
       stop
      endif

c    LSM to LSM2S
      nbo    = 0 ! initialize the number of bonds counter
      lib(1) = 0
      do ii=1,nthread2
      istart = layb(ii)+1 ! layer boundaries
      iend   = layb(ii+1) ! layer boundaries
      do i=istart,iend ! solid points loop
       do j=1,9 ! bond vectors loop (velocities9 file)
        npc(1:3)=icors(1:3,i)+ib(1:3,j) ! coordinates of the point adjacent to i by bond j
        nx1=icors(1,i)
        ny1=icors(2,i)
        nz1=icors(3,i)
        nx=ipcx(npc(1)+1) ! apply periodic conditions
        ny=ipcy(npc(2)+1) ! apply periodic conditions
        nz=ipcz(npc(3)+1) ! apply periodic conditions
         if(inds(nx,ny,nz).eq.0) then ! the next point is solid (may be there is a bond)
         nx1=iicx(nx1+1) ! s.p. for F1-Fn=E
         ncube1=0
         ncube2=0
          if(j.le.3)then ! first three cases
           if(j.eq.1)then ! 1 0 0 bond
              if (ind(nx1,ny1,nz1).eq.0) then 
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                             ncube2=ncube2+1
              endif
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),nz1).eq.0) then 
                                             ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),iicz(nz1)).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),iicz(nz1)).eq.3) then
                                             ncube2=ncube2+1
              endif
          elseif(j.eq.2)then ! 0 1 0 bond
              if (ind(nx1,ny1,nz1).eq.0) then
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then
                                             ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,nz1).eq.0) then 
                                             ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,nz1).eq.3) then 
                                             ncube2=ncube2+1
              endif
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then 
                                             ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then 
                                             ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,iicz(nz1)).eq.0) then
                                                     ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,iicz(nz1)).eq.3) then
                                                      ncube2=ncube2+1
              endif
           elseif(j.eq.3)then ! 0 0 1 bond
              if (ind(nx1,ny1,nz1).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,nz1).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,nz1).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),nz1).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),iicy(ny1),nz1).eq.0) then
                                                     ncube1=ncube1+1
              elseif (ind(iicx(nx1),iicy(ny1),nz1).eq.3) then
                                                      ncube2=ncube2+1
              endif
           endif
           ncube=ncube1+ncube2
           if(ncube.gt.0)then
           bconst1 = ncube1*0.25D0 ! bond constant component 1
           bconst2 = ncube2*0.25D0 ! bon constant compnent 2
           nbo=nbo+1 ! there is a bond
           bon(1,nbo)=i ! point 'from'
           bon(2,nbo)=mijks(nx,ny,nz) ! point 'to'
           bon(3,nbo)=j ! bond vector index 'from'->'to'
           sbond1(nbo)=bconst1 ! bond elastic constant
           sbond2(nbo)=bconst2
          endif
         else ! last six cases
           if(j.eq.4)then ! 1 1 0
c           ncube=ind(nx1,ny1,nz1)+ind(nx1,ny1,iicz(nz1))
              if (ind(nx1,ny1,nz1).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then
                                              ncube2=ncube2+1
              endif
          elseif(j.eq.5)then ! 1 -1 0
c           ncube=ind(nx1,iicy(ny1),nz1)+ind(nx1,iicy(ny1),iicz(nz1))

              if (ind(nx1,iicy(ny1),nz1).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then 
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),iicz(nz1)).eq.0) then
                                                         ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),iicz(nz1)).eq.3) then
                                                         ncube2=ncube2+1
              endif
           elseif(j.eq.6)then ! 1 0 1
c           ncube=ind(nx1,ny1,nz1)+ind(nx1,iicy(ny1),nz1)
              if (ind(nx1,ny1,nz1).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then 
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),nz1).eq.0) then
                                              ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),nz1).eq.3) then
                                              ncube2=ncube2+1
              endif

          elseif(j.eq.7)then ! 1 0 -1
c           ncube=ind(nx1,ny1,iicz(nz1))+ind(nx1,iicy(ny1),iicz(nz1))
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then 
                                              ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then
                                              ncube2=ncube2+1
              endif
              if (ind(nx1,iicy(ny1),iicz(nz1)).eq.0) then
                                                         ncube1=ncube1+1
              elseif (ind(nx1,iicy(ny1),iicz(nz1)).eq.3) then
                                                         ncube2=ncube2+1
              endif

          elseif(j.eq.8)then ! 0 1 1
c           ncube=ind(nx1,ny1,nz1)+ind(iicx(nx1),ny1,nz1)
              if (ind(nx1,ny1,nz1).eq.0) then
                                               ncube1=ncube1+1
              elseif (ind(nx1,ny1,nz1).eq.3) then
                                               ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,nz1).eq.0) then
                                                         ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,nz1).eq.3) then
                                                         ncube2=ncube2+1
              endif
          elseif(j.eq.9)then ! 0 1 -1
c           ncube=ind(nx1,ny1,iicz(nz1))+ind(iicx(nx1),ny1,iicz(nz1))
              if (ind(nx1,ny1,iicz(nz1)).eq.0) then
                                                 ncube1=ncube1+1
              elseif (ind(nx1,ny1,iicz(nz1)).eq.3) then
                                                 ncube2=ncube2+1
              endif
              if (ind(iicx(nx1),ny1,iicz(nz1)).eq.0) then
                                                         ncube1=ncube1+1
              elseif (ind(iicx(nx1),ny1,iicz(nz1)).eq.3) then
                                                         ncube2=ncube2+1
              endif
          endif
          ncube=ncube1+ncube2
          if(ncube.gt.0)then
           bconst1 = ncube1*0.5D0 ! bond constant
           bconst2 = ncube2*0.5D0 ! bond constant component 2
           nbo=nbo+1 ! there is a bond
           bon(1,nbo)=i ! point 'from'
           bon(2,nbo)=mijks(nx,ny,nz) ! point 'to'
           bon(3,nbo)=j ! bond vector index 'from'->'to'
           sbond1(nbo)=bconst1 ! bond elastic constant
           sbond2(nbo)=bconst2 ! compo 2
          endif
         endif
        endif
       enddo
      enddo
      lib(ii+1)=nbo
      enddo

      nna = 0 ! initialize the number of angles counter
      nn1=0
      do i=1,ns ! solid points loop
       do j=1,48 ! angles loop (angle i-j-k)
        npj(1:3)=icors(1:3,i)+iv(1:3,nta(1,j)) ! coordinates of the point j (i-j)
        nxj=ipcx(npj(1)+1) ! apply periodic conditions
        nyj=ipcy(npj(2)+1) ! apply periodic conditions
        nzj=ipcz(npj(3)+1) ! apply periodic conditions

        npk(1:3)=icors(1:3,i)+iv(1:3,nta(2,j)) ! coordinates of the point k (i-k)
        nxk=ipcx(npk(1)+1) ! apply periodic conditions
        nyk=ipcy(npk(2)+1) ! apply periodic conditions
        nzk=ipcz(npk(3)+1) ! apply periodic conditions

        nx1=icors(1,i) ! top point coordinates
        ny1=icors(2,i)
        nz1=icors(3,i)

        if(inds(nxj,nyj,nzj).eq.0.and.inds(nxk,nyk,nzk).eq.0) then ! may be there is an angle
         if(nta(1,j).gt.7.and.nta(2,j).gt.7)then ! only one cube possible
          inx1=iicx(min(nx1,npj(1),npk(1))+1)
          iny1=iicy(min(ny1,npj(2),npk(2))+1)
          inz1=iicz(min(nz1,npj(3),npk(3))+1)
          iscube = ind(inx1,iny1,inz1)
          if(iscube.eq.0.or.iscube.eq.3)then ! there is a cube and so there is an angle
           nna=nna+1 ! there is an angle i-j-k
           nn1=nn1+1
          endif
         else ! two cubes possible
          jv=iv(1:3,nta(1,j))
          kv=iv(1:3,nta(2,j))
          iscube1=0
          iscube2=0
          if(jv(1).eq.0.and.kv(1).eq.0)then ! yz plane
           inx1=iicx(min(nx1,npj(1),npk(1))+1)
           iny1=iicy(min(ny1,npj(2),npk(2))+1)
           inz1=iicz(min(nz1,npj(3),npk(3))+1)
c           iscube = ind(inx1,iny1,inz1)+ind(iicx(inx1),iny1,inz1)
              if (ind(inx1,iny1,inz1).eq.0) then
                                             iscube1=iscube1+1
              elseif (ind(inx1,iny1,inz1).eq.3) then 
                                             iscube2=iscube2+1
              endif
              if (ind(iicx(inx1),iny1,inz1).eq.0) then
                                                     iscube1=iscube1+1
              elseif (ind(iicx(inx1),iny1,inz1).eq.3) then
                                                     iscube2=iscube2+1
              endif
          elseif(jv(2).eq.0.and.kv(2).eq.0)then ! xz plane
           inx1=iicx(min(nx1,npj(1),npk(1))+1)
           iny1=iicy(min(ny1,npj(2),npk(2))+1)
           inz1=iicz(min(nz1,npj(3),npk(3))+1)
c           iscube = ind(inx1,iny1,inz1)+ind(inx1,iicy(iny1),inz1)
              if (ind(inx1,iny1,inz1).eq.0) then
                                             iscube1=iscube1+1
              elseif (ind(inx1,iny1,inz1).eq.3) then 
                                             iscube2=iscube2+1
              endif
              if (ind(inx1,iicy(iny1),inz1).eq.0) then
                                                     iscube1=iscube1+1
              elseif (ind(inx1,iicy(iny1),inz1).eq.3) then
                                                     iscube2=iscube2+1
              endif
          elseif(jv(3).eq.0.and.kv(3).eq.0)then ! xy plane
           inx1=iicx(min(nx1,npj(1),npk(1))+1)
           iny1=iicy(min(ny1,npj(2),npk(2))+1)
           inz1=iicz(min(nz1,npj(3),npk(3))+1)
c           iscube = ind(inx1,iny1,inz1)+ind(inx1,iny1,iicz(inz1))
              if (ind(inx1,iny1,inz1).eq.0) then
                                             iscube1=iscube1+1
              elseif (ind(inx1,iny1,inz1).eq.3) then 
                                             iscube2=iscube2+1
              endif
              if (ind(inx1,iny1,iicz(inz1)).eq.0) then
                                                     iscube1=iscube1+1
              elseif (ind(inx1,iny1,iicz(inz1)).eq.3) then
                                                     iscube2=iscube2+1
              endif
          endif
          iscube=0
          iscube=iscube1+iscube2
          if(iscube.gt.0)then ! there is an angle
           nna=nna+1 ! there is an angle i-j-k
          endif
         endif
        endif
       enddo
      enddo


      allocate(ang(6,nna),stat=checkstat) ! create ang - angles array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ang'
       stop
      endif

      allocate(abond(nna),stat=checkstat) ! create abond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for abond'
       stop
      endif
      allocate(abond1(nna),stat=checkstat) ! create abond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for abond'
       stop
      endif
      allocate(abond2(nna),stat=checkstat) ! create abond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for abond'
       stop
      endif
      allocate(abondin(nna),stat=checkstat) ! create sbond - surface bonds indicator array
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sbond'
       stop
      endif

  !  LSM to LSM2S
      nna = 0 ! initialize the number of angles counter
      nn1=0
      lia (1) = 0
      do ii=1,nthread2
      istart = layb(ii)+1 ! layer boundaries
      iend   = layb(ii+1) ! layer boundaries
      do i=istart,iend ! solid points loop
       do j=1,48 ! angles loop (angle i-j-k)
        npj(1:3)=icors(1:3,i)+iv(1:3,nta(1,j)) ! coordinates of the point j (i-j)
        nxj=ipcx(npj(1)+1) ! apply periodic conditions
        nyj=ipcy(npj(2)+1) ! apply periodic conditions
        nzj=ipcz(npj(3)+1) ! apply periodic conditions

        npk(1:3)=icors(1:3,i)+iv(1:3,nta(2,j)) ! coordinates of the point k (i-k)
        nxk=ipcx(npk(1)+1) ! apply periodic conditions
        nyk=ipcy(npk(2)+1) ! apply periodic conditions
        nzk=ipcz(npk(3)+1) ! apply periodic conditions

        nx1=icors(1,i) ! top point coordinates
        ny1=icors(2,i)
        nz1=icors(3,i)

        if(inds(nxj,nyj,nzj).eq.0.and.inds(nxk,nyk,nzk).eq.0) then ! may be there is an angle
         if(nta(1,j).gt.7.and.nta(2,j).gt.7)then ! only one cube possible
          inx1=iicx(min(nx1,npj(1),npk(1))+1)
          iny1=iicy(min(ny1,npj(2),npk(2))+1)
          inz1=iicz(min(nz1,npj(3),npk(3))+1)
          iscube = ind(inx1,iny1,inz1)
          if(iscube.eq.0)then ! there is a cube and so there is an angle
           nna=nna+1 ! there is an angle i-j-k
           nn1=nn1+1
           ang(1,nna)=i ! angle top point i
           ang(2,nna)=mijks(nxj,nyj,nzj) ! angleside endpoint j
           ang(3,nna)=mijks(nxk,nyk,nzk) ! angleside endpoint k
           ang(4,nna)=nta(1,j) ! i-j vector index
           ang(5,nna)=nta(2,j) ! i-k vector index
           ang(6,nna)=j ! angle indentificator
           abond1(nna)=1.D0 ! elastic constant
           abond2(nna)=0.D0 ! elastic constan of angular spring compo 2
          endif
           if(iscube.eq.3)then ! there is a cube and so there is an angle
           nna=nna+1 ! there is an angle i-j-k
           nn1=nn1+1
           ang(1,nna)=i ! angle top point i
           ang(2,nna)=mijks(nxj,nyj,nzj) ! angleside endpoint j
           ang(3,nna)=mijks(nxk,nyk,nzk) ! angleside endpoint k
           ang(4,nna)=nta(1,j) ! i-j vector index
           ang(5,nna)=nta(2,j) ! i-k vector index
           ang(6,nna)=j ! angle indentificator
           abond1(nna)=0.D0 ! elastic constant
           abond2(nna)=1.D0 ! elastic constan of angular spring compo 2
          endif
         else ! two cubes possible
          jv=iv(1:3,nta(1,j))
          kv=iv(1:3,nta(2,j))
          iscube1=0
          iscube2=0
          if(jv(1).eq.0.and.kv(1).eq.0)then ! yz plane
           inx1=iicx(min(nx1,npj(1),npk(1))+1)
           iny1=iicy(min(ny1,npj(2),npk(2))+1)
           inz1=iicz(min(nz1,npj(3),npk(3))+1)
c           iscube = ind(inx1,iny1,inz1)+ind(iicx(inx1),iny1,inz1)
              if (ind(inx1,iny1,inz1).eq.0) then
                                             iscube1=iscube1+1
              elseif (ind(inx1,iny1,inz1).eq.3) then
                                             iscube2=iscube2+1
              endif
              if (ind(iicx(inx1),iny1,inz1).eq.0) then
                                                     iscube1=iscube1+1
              elseif (ind(iicx(inx1),iny1,inz1).eq.3) then
                                                     iscube2=iscube2+1
              endif
           elseif(jv(2).eq.0.and.kv(2).eq.0)then ! xz plane
           inx1=iicx(min(nx1,npj(1),npk(1))+1)
           iny1=iicy(min(ny1,npj(2),npk(2))+1)
           inz1=iicz(min(nz1,npj(3),npk(3))+1)
c           iscube = ind(inx1,iny1,inz1)+ind(inx1,iicy(iny1),inz1)
              if (ind(inx1,iny1,inz1).eq.0) then
                                             iscube1=iscube1+1
              elseif (ind(inx1,iny1,inz1).eq.3) then
                                             iscube2=iscube2+1
              endif
              if (ind(inx1,iicy(iny1),inz1).eq.0) then
                                                     iscube1=iscube1+1
              elseif (ind(inx1,iicy(iny1),inz1).eq.3) then
                                                     iscube2=iscube2+1
              endif
          elseif(jv(3).eq.0.and.kv(3).eq.0)then ! xy plane
           inx1=iicx(min(nx1,npj(1),npk(1))+1)
           iny1=iicy(min(ny1,npj(2),npk(2))+1)
           inz1=iicz(min(nz1,npj(3),npk(3))+1)
c           iscube = ind(inx1,iny1,inz1)+ind(inx1,iny1,iicz(inz1))
              if (ind(inx1,iny1,inz1).eq.0) then
                                             iscube1=iscube1+1
              elseif (ind(inx1,iny1,inz1).eq.3) then
                                             iscube2=iscube2+1
              endif
              if (ind(inx1,iny1,iicz(inz1)).eq.0) then
                                                     iscube1=iscube1+1
              elseif (ind(inx1,iny1,iicz(inz1)).eq.3) then
                                                     iscube2=iscube2+1
              endif
          endif
          iscube=iscube1+iscube2
          if(iscube.gt.0)then ! there is an angle
           nna=nna+1 ! there is an angle i-j-k
           nn1=nn1+1
           ang(1,nna)=i ! angle top point i
           ang(2,nna)=mijks(nxj,nyj,nzj) ! angleside endpoint j
           ang(3,nna)=mijks(nxk,nyk,nzk) ! angleside endpoint k
           ang(4,nna)=nta(1,j) ! i-j vector index
           ang(5,nna)=nta(2,j) ! i-k vector index
           ang(6,nna)=j ! angle indentificator
           abond1(nna)=iscube1*0.5D0 ! elastic constant
           abond2(nna)=iscube2*0.5D0 ! elastic constan of angular spring compo 2
          endif
         endif
        endif
       enddo
      enddo
      lia(ii+1)=nna
      enddo
c      write(*,*)nna,nn1

      allocate(adat(3,ns),stat=checkstat) ! create adat
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for adat'
       stop
      endif

      allocate(vdat(3,ns),stat=checkstat) ! create vdat
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for vdat'
       stop
      endif

      allocate(rdat(3,ns),stat=checkstat) ! create rdat
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for rdat'
       stop
      endif

! Initialize the adat,vdat,rdat arrays
      adat = 0.d0 ! initialize acceleration, velocity with zeroes
      vdat = 0.d0
      rdat = 0.D0

! Calculate unit cell directions vectors
      vn(1:3,1) = vv(1:3,1) ! first is zero vector
      vx(1:3,1) = vv(1:3,1) ! first is zero vector
      vnr(1) = 0.d0 ! norm is zero
      vni(1) = 0.d0 ! zero (this one is not used anyway)
      do i=2,19 ! normalization of direction vectors and norms calculation
       vnr(i) = sqrt(dot_product(vv(1:3,i),vv(1:3,i))) ! norms
       vni(i) = 1.d0/vnr(i) ! norms inverse
       vn(1:3,i) = vv(1:3,i)/vnr(i) ! normalized vectors
       vx(1:3,i) = vv(1:3,i)/(dot_product(vv(1:3,i),vv(1:3,i))) ! xn/|rn|
      enddo

      do i=1,9 ! normalization of bond vectors and norms calculation
       vbn(i) = sqrt(dot_product(vb(1:3,i),vb(1:3,i))) ! norms
       vbi(i) = 1.d0/vbn(i) ! norms inverse
       bn(1:3,i) = vb(1:3,i)/vbn(i) ! normalized vectors
       bx(1:3,i) = vb(1:3,i)/(dot_product(vb(1:3,i),vb(1:3,i))) ! xn/|rn|
      enddo

      sbond = sbond1*alf1+sbond2*alf2
      abond = abond1*bet1+abond2*bet2

! LSM code end

      sig = 0.03125D0*sig ! surface tension parameter for calculations

! LBM geometry new variant start
c___________________________________________________
c     part 4: define liquid points
c___________________________________________________
      open(12,file='ind') ! open medium structure index file (1-pore, 0-solid)
      write(format211,*)'(" ",',ncx,'i1)' ! create format to read from 'ind'
      do k=1,ncz
       do j=1,ncy
        read(12,fmt=format211)(ind(i,j,k),i=1,ncx) ! read structure data from the file
       enddo
      enddo
      close(12)

      nl=0                 ! number of liquid points
      do i=1,ncx           ! define coordinates and numbers of liquid points
       do j=1,ncy
        do k=1,ncz
         if(ind(i,j,k).eq.iipore) then ! define fluid filed pore
          nl=nl+1
         endif
        enddo
       enddo
      enddo

      allocate(icor(3,nl),stat=checkstat)        ! create icor
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for icor'
       stop
      endif

      allocate(mijk(ncx,ncy,ncz),stat=checkstat) ! create mijk
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for mijk'
       stop
      endif

      mijk=0               ! initialize
      nl=0                 ! number of liquid points
      do i=1,ncx           ! define coordinates and numbers of liquid points
       do j=1,ncy
        do k=1,ncz
         if(ind(i,j,k).eq.iipore) then
          nl=nl+1
          icor(1,nl)=i     ! define coordinate of the liquid point
          icor(2,nl)=j
          icor(3,nl)=k
          mijk(i,j,k)=nl   ! assign the number to the liquid point
         endif
        enddo
       enddo
      enddo

c___________________________________________________
c     part 5: define propagation rules
c___________________________________________________
      nps  = 0;                         ! indices for propagation rules tables
      npb2 = 0;
      npb4 = 0;
      npm  = 0;

      do i=1,nl                        ! liquid points circle
       do j=2,7                       ! iv(1)=(0,0,0) !!!
        npc(1:3)=icor(1:3,i)+iv(1:3,j) ! coordinates of the point adjacent to i by velocity j
        nx=ipcx(npc(1)+1)     ! apply periodic conditions
        ny=ipcy(npc(2)+1)     ! apply periodic conditions
        nz=ipcz(npc(3)+1)     ! apply periodic conditions
        if(mijk(nx,ny,nz).ne.0) then
         nps=nps+1                     ! simple propagation
        else
         npb4=npb4+1                        ! bounce-back
        endif
       enddo

       do j=8,19                       ! iv(1)=(0,0,0) !!!
        npc(1:3)=icor(1:3,i)+iv(1:3,j) ! coordinates of the point adjacent to i by velocity j
        nx=ipcx(npc(1)+1)     ! apply periodic conditions
        ny=ipcy(npc(2)+1)     ! apply periodic conditions
        nz=ipcz(npc(3)+1)     ! apply periodic conditions
        if(mijk(nx,ny,nz).eq.0) then
         npb2=npb2+1                        ! bounce-back
        else
         npc1(1:3)=icor(1:3,i)+(/iv(1,j),0,0/)
         nx1=ipcx(npc1(1)+1)    ! apply periodic conditions
         ny1=ipcy(npc1(2)+1)    ! apply periodic conditions
         nz1=ipcz(npc1(3)+1)    ! apply periodic conditions

         npc2(1:3)=icor(1:3,i)+(/0,iv(2,j),0/) !
         nx2=ipcx(npc2(1)+1)    ! apply periodic conditions
         ny2=ipcy(npc2(2)+1)    ! apply periodic conditions
         nz2=ipcz(npc2(3)+1)    ! apply periodic conditions

         npc3(1:3)=icor(1:3,i)+(/0,0,iv(3,j)/) !
         nx3=ipcx(npc3(1)+1)      ! apply periodic conditions
         ny3=ipcy(npc3(2)+1)      ! apply periodic conditions
         nz3=ipcz(npc3(3)+1)      ! apply periodic conditions

         nsum=mijk(nx1,ny1,nz1)*mijk(nx2,ny2,nz2)*mijk(nx3,ny3,nz3)

         if(nsum.ne.0)then
          nps=nps+1                     ! simple propagation
         else
          npb2=npb2+1                        ! bounce-back
         endif
        endif
       enddo
      enddo

      allocate(ips(3,nps),stat=checkstat)        ! create ips
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ips'
       stop
      endif

c      allocate(ipb(2,npb),stat=checkstat)        ! create ipb
c      if(checkstat>0) then
c       write(*,*)'ERROR! impossible to allocate memory for ipb'
c       stop
c      endif

      allocate(ipb2(4,npb2),stat=checkstat)        ! create ipb4
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ipb4'
       stop
      endif

      allocate(ipb4(6,npb4),stat=checkstat)        ! create ipb4
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for ipb4'
       stop
      endif

      nps  = 0;                         ! indices for propagation rules tables
      npb2 = 0;
      npb4 = 0;
      npm  = 0;

      do i=1,nl                        ! liquid points circle
       do j=2,7                       ! iv(1)=(0,0,0) !!!
        npc(1:3)=icor(1:3,i)+iv(1:3,j) ! coordinates of the point adjacent to i by velocity j
        nx=ipcx(npc(1)+1)     ! apply periodic conditions
        ny=ipcy(npc(2)+1)     ! apply periodic conditions
        nz=ipcz(npc(3)+1)     ! apply periodic conditions
        if(mijk(nx,ny,nz).ne.0) then
         nps=nps+1                     ! simple propagation
         ips(1,nps)=i                  ! point 'from'
         ips(2,nps)=mijk(nx,ny,nz)     ! point 'to'
         ips(3,nps)=j                  ! velocity 'from'->'to'
        else
         if(iv(1,j).ne.0)then
          lp1=icor(1:3,i)+(/(iv(1,j)+1)/2,0,0/)
          lp2=icor(1:3,i)+(/(iv(1,j)+1)/2,1,0/)
          lp3=icor(1:3,i)+(/(iv(1,j)+1)/2,0,1/)
          lp4=icor(1:3,i)+(/(iv(1,j)+1)/2,1,1/)

          lp1(1)=ipcx(lp1(1)+1)
          lp1(2)=ipcy(lp1(2)+1)
          lp1(3)=ipcz(lp1(3)+1)
          lp2(1)=ipcx(lp2(1)+1)
          lp2(2)=ipcy(lp2(2)+1)
          lp2(3)=ipcz(lp2(3)+1)
          lp3(1)=ipcx(lp3(1)+1)
          lp3(2)=ipcy(lp3(2)+1)
          lp3(3)=ipcz(lp3(3)+1)
          lp4(1)=ipcx(lp4(1)+1)
          lp4(2)=ipcy(lp4(2)+1)
          lp4(3)=ipcz(lp4(3)+1)
         elseif(iv(2,j).ne.0)then
          lp1=icor(1:3,i)+(/0,(iv(2,j)+1)/2,0/)
          lp2=icor(1:3,i)+(/1,(iv(2,j)+1)/2,0/)
          lp3=icor(1:3,i)+(/0,(iv(2,j)+1)/2,1/)
          lp4=icor(1:3,i)+(/1,(iv(2,j)+1)/2,1/)

          lp1(1)=ipcx(lp1(1)+1)
          lp1(2)=ipcy(lp1(2)+1)
          lp1(3)=ipcz(lp1(3)+1)
          lp2(1)=ipcx(lp2(1)+1)
          lp2(2)=ipcy(lp2(2)+1)
          lp2(3)=ipcz(lp2(3)+1)
          lp3(1)=ipcx(lp3(1)+1)
          lp3(2)=ipcy(lp3(2)+1)
          lp3(3)=ipcz(lp3(3)+1)
          lp4(1)=ipcx(lp4(1)+1)
          lp4(2)=ipcy(lp4(2)+1)
          lp4(3)=ipcz(lp4(3)+1)
         elseif(iv(3,j).ne.0)then
          lp1=icor(1:3,i)+(/0,0,(iv(3,j)+1)/2/)
          lp2=icor(1:3,i)+(/1,0,(iv(3,j)+1)/2/)
          lp3=icor(1:3,i)+(/0,1,(iv(3,j)+1)/2/)
          lp4=icor(1:3,i)+(/1,1,(iv(3,j)+1)/2/)

          lp1(1)=ipcx(lp1(1)+1)
          lp1(2)=ipcy(lp1(2)+1)
          lp1(3)=ipcz(lp1(3)+1)
          lp2(1)=ipcx(lp2(1)+1)
          lp2(2)=ipcy(lp2(2)+1)
          lp2(3)=ipcz(lp2(3)+1)
          lp3(1)=ipcx(lp3(1)+1)
          lp3(2)=ipcy(lp3(2)+1)
          lp3(3)=ipcz(lp3(3)+1)
          lp4(1)=ipcx(lp4(1)+1)
          lp4(2)=ipcy(lp4(2)+1)
          lp4(3)=ipcz(lp4(3)+1)
         endif
         npb4=npb4+1                        ! bounce-back
         ipb4(1,npb4)=i                     ! boundary point
         ipb4(2,npb4)=niv(j)                ! back velocity '-j'
         ipb4(3,npb4)=mijks(lp1(1),lp1(2),lp1(3))
         ipb4(4,npb4)=mijks(lp2(1),lp2(2),lp2(3))
         ipb4(5,npb4)=mijks(lp3(1),lp3(2),lp3(3))
         ipb4(6,npb4)=mijks(lp4(1),lp4(2),lp4(3))
        endif
       enddo

       do j=8,19                       ! iv(1)=(0,0,0) !!!
        npc(1:3)=icor(1:3,i)+iv(1:3,j) ! coordinates of the point adjacent to i by velocity j
        nx=ipcx(npc(1)+1)     ! apply periodic conditions
        ny=ipcy(npc(2)+1)     ! apply periodic conditions
        nz=ipcz(npc(3)+1)     ! apply periodic conditions
        if(mijk(nx,ny,nz).eq.0) then
         if(iv(1,j).eq.0)then
          lp1=icor(1:3,i)+(/0,(iv(2,j)+1)/2,(iv(3,j)+1)/2/)
          lp2=icor(1:3,i)+(/1,(iv(2,j)+1)/2,(iv(3,j)+1)/2/)

          lp1(1)=ipcx(lp1(1)+1)
          lp1(2)=ipcy(lp1(2)+1)
          lp1(3)=ipcz(lp1(3)+1)
          lp2(1)=ipcx(lp2(1)+1)
          lp2(2)=ipcy(lp2(2)+1)
          lp2(3)=ipcz(lp2(3)+1)
         elseif(iv(2,j).eq.0)then
          lp1=icor(1:3,i)+(/(iv(1,j)+1)/2,0,(iv(3,j)+1)/2/)
          lp2=icor(1:3,i)+(/(iv(1,j)+1)/2,1,(iv(3,j)+1)/2/)

          lp1(1)=ipcx(lp1(1)+1)
          lp1(2)=ipcy(lp1(2)+1)
          lp1(3)=ipcz(lp1(3)+1)
          lp2(1)=ipcx(lp2(1)+1)
          lp2(2)=ipcy(lp2(2)+1)
          lp2(3)=ipcz(lp2(3)+1)
         elseif(iv(3,j).eq.0)then
          lp1=icor(1:3,i)+(/(iv(1,j)+1)/2,(iv(2,j)+1)/2,0/)
          lp2=icor(1:3,i)+(/(iv(1,j)+1)/2,(iv(2,j)+1)/2,1/)

          lp1(1)=ipcx(lp1(1)+1)
          lp1(2)=ipcy(lp1(2)+1)
          lp1(3)=ipcz(lp1(3)+1)
          lp2(1)=ipcx(lp2(1)+1)
          lp2(2)=ipcy(lp2(2)+1)
          lp2(3)=ipcz(lp2(3)+1)
         endif
         npb2=npb2+1                        ! bounce-back
         ipb2(1,npb2)=i                     ! boundary point
         ipb2(2,npb2)=niv(j)                ! back velocity '-j'
         ipb2(3,npb2)=mijks(lp1(1),lp1(2),lp1(3))
         ipb2(4,npb2)=mijks(lp2(1),lp2(2),lp2(3))
        else
         npc1(1:3)=icor(1:3,i)+(/iv(1,j),0,0/)
         nx1=ipcx(npc1(1)+1)    ! apply periodic conditions
         ny1=ipcy(npc1(2)+1)    ! apply periodic conditions
         nz1=ipcz(npc1(3)+1)    ! apply periodic conditions

         npc2(1:3)=icor(1:3,i)+(/0,iv(2,j),0/) !
         nx2=ipcx(npc2(1)+1)    ! apply periodic conditions
         ny2=ipcy(npc2(2)+1)    ! apply periodic conditions
         nz2=ipcz(npc2(3)+1)    ! apply periodic conditions

         npc3(1:3)=icor(1:3,i)+(/0,0,iv(3,j)/) !
         nx3=ipcx(npc3(1)+1)      ! apply periodic conditions
         ny3=ipcy(npc3(2)+1)      ! apply periodic conditions
         nz3=ipcz(npc3(3)+1)      ! apply periodic conditions

         nsum=mijk(nx1,ny1,nz1)*mijk(nx2,ny2,nz2)*mijk(nx3,ny3,nz3)

         if(nsum.ne.0)then
          nps=nps+1                     ! simple propagation
          ips(1,nps)=i                  ! point 'from'
          ips(2,nps)=mijk(nx,ny,nz)     ! point 'to'
          ips(3,nps)=j                  ! velocity 'from'->'to'
         else
          if(iv(1,j).eq.0)then
           lp1=icor(1:3,i)+(/0,(iv(2,j)+1)/2,(iv(3,j)+1)/2/)
           lp2=icor(1:3,i)+(/1,(iv(2,j)+1)/2,(iv(3,j)+1)/2/)

           lp1(1)=ipcx(lp1(1)+1)
           lp1(2)=ipcy(lp1(2)+1)
           lp1(3)=ipcz(lp1(3)+1)
           lp2(1)=ipcx(lp2(1)+1)
           lp2(2)=ipcy(lp2(2)+1)
           lp2(3)=ipcz(lp2(3)+1)
          elseif(iv(2,j).eq.0)then
           lp1=icor(1:3,i)+(/(iv(1,j)+1)/2,0,(iv(3,j)+1)/2/)
           lp2=icor(1:3,i)+(/(iv(1,j)+1)/2,1,(iv(3,j)+1)/2/)

           lp1(1)=ipcx(lp1(1)+1)
           lp1(2)=ipcy(lp1(2)+1)
           lp1(3)=ipcz(lp1(3)+1)
           lp2(1)=ipcx(lp2(1)+1)
           lp2(2)=ipcy(lp2(2)+1)
           lp2(3)=ipcz(lp2(3)+1)
          elseif(iv(3,j).eq.0)then
           lp1=icor(1:3,i)+(/(iv(1,j)+1)/2,(iv(2,j)+1)/2,0/)
           lp2=icor(1:3,i)+(/(iv(1,j)+1)/2,(iv(2,j)+1)/2,1/)

           lp1(1)=ipcx(lp1(1)+1)
           lp1(2)=ipcy(lp1(2)+1)
           lp1(3)=ipcz(lp1(3)+1)
           lp2(1)=ipcx(lp2(1)+1)
           lp2(2)=ipcy(lp2(2)+1)
           lp2(3)=ipcz(lp2(3)+1)
          endif
          npb2=npb2+1                        ! bounce-back
          ipb2(1,npb2)=i                     ! boundary point
          ipb2(2,npb2)=niv(j)                ! back velocity '-j'
          ipb2(3,npb2)=mijks(lp1(1),lp1(2),lp1(3))
          ipb2(4,npb2)=mijks(lp2(1),lp2(2),lp2(3))
         endif
        endif
       enddo
      enddo

      do k=1,ncz
       do j=1,ncy
        do i=1,ncx
         if(ind(i,j,k).gt.1)then ! make all pores ind = 1
          ind(i,j,k)=1
         endif
        enddo
       enddo
      enddo
! LBM geometry new variant end

      t0=ncx*ncy*ncz                         ! unit cell volume

      c1d6     = 1.D0/6.D0                   ! numerical constants
      c1d12    = 1.D0/12.D0
      c5d399   = 5.D0/399.D0
      c19d399  = 19.D0/399.D0
      c11d2394 = 11.D0/2394.D0
      c1d63    = 1.D0/63.D0
      c1d18    = 1.D0/18.D0
      c1d36    = 1.D0/36.D0
      c4d1197  = 4.D0/1197.D0
      c1d252   = 1.D0/252.D0
      c1d72    = 1.D0/72.D0
      c1d24    = 1.D0/24.D0

      cb2=rr0*cr2/rb0                                          ! blue fluid sound speed
      tr1=1.D0-2.D0*cr2*dt*dt
      tr2=cr2*dt*dt*c1d6
      tr3=cr2*dt*dt*c1d12  ! red lattice weigths
      tb1=1.D0-2.D0*cb2*dt*dt
      tb2=cb2*dt*dt*c1d6
      tb3=cb2*dt*dt*c1d12  ! blue lattice weigths
      tr=(/tr1,(tr2,i=1,6),(tr3,i=1,12)/) ! red lattice weigths
      tb=(/tb1,(tb2,i=1,6),(tb3,i=1,12)/) ! blue lattice weigths
      
      svr = 1.D0/(3.D0*vir*dt+0.5D0)
      svb = 1.D0/(3.D0*vib*dt+0.5D0)
    
      call collmatrTRT(svr,Sr)  ! create red  fluid collision vector  
      call collmatrTRT(svb,Sb)  ! create blue fluid collision vector

c      q=1.D0/2.D0                               ! coefficients for multireflection
c      q1=(1.D0-2.D0*q-2.D0*q**2)/((1.D0+q)**2)
c      q2=(q**2)/((1.D0+q)**2)
c      q3=1.D0/(4.D0*nu*((1.D0+q)**2))

      allocate(fr(19,nl),stat=checkstat)         ! create fr (particle populations)
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for fr'
       stop
      endif

      allocate(pcfr(19,nl),stat=checkstat)       ! red post collision particle populations
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for pcfr'
       stop
      endif

      allocate(fb(19,nl),stat=checkstat)         ! create fb (particle populations)
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for fb'
       stop
      endif

      allocate(pcfb(19,nl),stat=checkstat)       ! blue post collision particle populations
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for pcfb'
       stop
      endif

      call initdistr(fr,fb,nl,rr0,rb0,tr,tb,icon,itms,sat) ! initialize distribution functions

      if(icon.eq.0)then
       open(1,file='output.m')                           ! clean the output file
       write(1,*)'% 1 - iteration'
       write(1,*)'% 2 - red  permeability'
       write(1,*)'% 3 - blue permeability'
       write(1,*)'% 4 - red capillary number, volume average'
       write(1,*)'% 5 - blue capillary number, volume average'
       write(1,*)'% 6 - red capillary number, phase average'
       write(1,*)'% 7 - blue capillary number, phase average'
       write(1,*)'% 8 - capillary pressure P_r - P_b, phase average'
       write(1,*)'% 9 - capillary pressure P_red, phase average'
       write(1,*)'% 10 - capillary pressure P_blue, phase average'
       write(1,*)'% 11 - saturation red = number of red/number'
       write(1,*)'% 12 - saturation blue = number of blue/number'  
       write(1,*)'out = ['
       close(1)
      
       open(1,file='ind_red_blue',status='replace')      ! clean the output file
       close(1)

       open(17,file='check_state_19',status='replace')   ! clean the output file
       close(17)
      endif
c___________________________________________________
c     part 2.1 save program settings
c___________________________________________________

      open(19,file='settings_19') 

      write(19,*)'LBM settings'
      write(19,*)'Physical parameters'

      write(19,*)'iipore = ',iipore
      write(19,*)'npores = ',npores

      write(19,*)'surface tension parameter sig = ',sig/0.03125D0
      write(19,*)'wettability parameter wet = ',wet

      write(19,*)'initial red fluid density rr0 = ',rr0
      write(19,*)'red fluid cinematic viscosity vir = ',vir
      write(19,*)'red fluid sound speed square cr2 = ',cr2
      write(19,*)'red fluid lattice weigts tr = ',tr
      write(19,*)'red fluid body force bfr = ',bfr
      write(19,*)'red fluid collision vector Sr = ',Sr

      write(19,*)'initial blue fluid density rb0 = ',rb0
      write(19,*)'blue fluid cinematic viscosity vib = ',vib
      write(19,*)'blue fluid sound speed square cb2 = ',cb2
      write(19,*)'blue fluid lattice weigts tb = ',tb
      write(19,*)'blue fluid body force bfb = ',bfb
      write(19,*)'blue fluid collision vector Sb = ',Sb

      write(19,*)'Computational domain properties'

      write(19,*)'Unit cell size xyz = ',ncx,'x',ncy,'x',ncz
      write(19,*)'number of liquid points nl = ',nl
      write(19,*)'simple propagation entries nps = ',nps
      write(19,*)'bounce-back boundary condition entries npb2 = ',npb2
      write(19,*)'bounce-back boundary condition entries npb4 = ',npb4
      write(19,*)'multirefletion boundary condition entries npm = ',npm
      write(19,*)'linear size for Reynolds number lsize = ',lsize

      write(19,*)'Lattice Boltzmann algorithm parameters'

      write(19,*)'interface width parameter B = ',B
      write(19,*)'direction of the body force idir = ',idir
      write(19,*)'number of steps in the main loop itm = ',itm
      write(19,*)'number of steps in the inner loop itw = ',itw
      write(19,*)'save parameter its = ',its
      write(19,*)'permeability convergence test parameter eps = ',eps
      write(19,*)'LBM type (1 - interpolation) mtype = ',mtype
      write(19,*)'read initial state data from archiv? icon = ',icon
      write(19,*)'small number to supress small distributions ee = ',ee

      write(19,*)'LSM settings'
      write(19,*)'Physical parameters'
      write(19,*)'Physical parameters'
      write(19,*)'Young modulus Em = ',Em
      write(19,*)'Poissons ratio nu = ',nu
      write(19,*)'linear spring parameter alf = ',alf
      write(19,*)'angular spring parameter bet = ',bet
      write(19,*)'solid medium density rs = ',rs
      write(19,*)'integration time step dt = ',dt
      write(19,*)'lattice unit step dl = ',dl

      write(19,*)'Computational domain properties'
      write(19,*)'x unit cell size ncx = ',ncx
      write(19,*)'y unit cell size ncy = ',ncy
      write(19,*)'z unit cell size ncz = ',ncz
      write(19,*)'number of solid points ns = ',ns

      write(19,*)'LSM algorithm parameters'
      write(19,*)'nbo = ',nbo
      write(19,*)'nna = ',nna
      write(19,*)'layers = ',(layers(i),i=1,2*nthread)
      write(19,*)'layb = ',(layb(i),i=1,2*nthread+1)
      write(19,*)'lib = ',(lib(i),i=1,2*nthread+1)
      write(19,*)'lia = ',(lia(i),i=1,2*nthread+1)

      close(19)
c___________________________________________________
c     part 3: calculate flow 
c___________________________________________________
c      open(919,file='antidiffusion')
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'initialization end = ',time

      if(mtype.eq.0)then
       call majorityrule(ipcx,ipcy,ipcz,ind,c1d6,c1d12,c5d399,c19d399,
     &  c11d2394,c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72,
     &  c1d24,tr1,tr2,tr3,tb1,tb2,tb3,itm,itw,nl,fr,fb,ee,bfr,
     &  bfb,ncx,ncy,ncz,mijk,sig,wet,Sr,Sb,cb2,cr2,icor,
     &  svr,svb,B,nps,ips,npb2,ipb2,npb4,ipb4,iv,niv,idir,t0,
     &  lsize,rr0,rb0,eps,its,itms,ns,rdat,vdat,dt,adat,icors,
     &  nbo,bn,bon,bx,vb,alf1,bet1,alf2,bet2,
     &  nna,vn,ang,vx,vv,anf,rsi,mijks,
     &  abond,sbond,nthread2,lib,lia,Em,nu,inds,iipore,npores)

      elseif(mtype.eq.1)then
       call interpolationrule(ipcx,ipcy,ipcz,ind,c1d6,c1d12,c5d399
     &  ,c19d399,c11d2394,c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72,
     &  c1d24,tr1,tr2,tr3,tb1,tb2,tb3,itm,itw,nl,fr,fb,ee,bfr,
     &  bfb,ncx,ncy,ncz,mijk,sig,wet,Sr,Sb,cb2,cr2,icor,
     &  svr,svb,B,nps,ips,npb,ipb,iv,niv,idir,t0,
     &  lsize,rr0,rb0,eps,its,itms,ns,rdat,vdat,dt,adat,icors,
     &  nbo,bn,bon,bx,vb,alf1,bet1,alf2,bet2,
     &  nna,vn,ang,vx,vv,anf,rsi,mijks)
      endif

c     call check_laplace(nl,rr,rb,cf,cr2,cb2)                         ! check Laplace's law
      open(1,file='output.m',position='append')
      write(1,*)'];'
      close(1)

      deallocate(ipcx,ipcy,ipcz,ind,icor,mijk,ips,ipb2,ipb4,fr,fb,pcfr
     &          ,pcfb)  ! release memory
      deallocate(bon,ang,icors,mijks,adat,vdat,rdat)

c211   format(' ',64i1) 
213   format(14i10)
214   format(f11.7)
215   format(19f11.7)
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'program stop = ',time

      stop
      end
c___________________________________________________
c     subroutines
c___________________________________________________
c     calcIMP - acoustic impendance
c___________________________________________________
      subroutine calcIMP(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz
     &                 ,cf,nl,ic,Cg,Fs,sig,wet,rr,rb)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      integer*4 ncx               ! x unit cell size
      integer*4 ncy               ! y unit cell size
      integer*4 ncz               ! z unit cell size
      integer*4 mijk(ncx,ncy,ncz) ! liquid points numbers
      integer*4 ic(3)             ! interface point coordinates
      integer*4 x,y,z             ! liquid point coordinates

      real*8 cf(nl),rr(nl),rb(nl) ! color field
      real*8 Cg(3)                ! color gradient
      real*8 Fs(3)                ! surface tension force
      real*8 sig                  ! surface tension force parameter
      real*8 wet                  ! wettability parameter

      real*8 c(1:3,1:3,1:3)       ! color field part
      real*8 nm(1:8,1:3)          ! color field gradients in 8 intermediate points
      real*8 mm(8)                ! color field gradients modulus in 8 intermediate points
      real*8 norm,normc           ! vector norm
      real*8 dn(3)                ! color field gradient gradient
      real*8 dm(3)                ! color field gradient gradient modulus
      real*8 k1,k2                ! curvature components
      real*8 r11,r12,r13,r14,r15,r16,r17,r18,r19,r110,r111,r112 !edges
      real*8 r21,r22,r23,r24,r25,r26,r27,r28,r29,r210,r211,r212
      real*8 r31,r32,r33,r34,r35,r36,r37,r38,r39,r310,r311,r312
      real*8 g68,g78,g57,g56,g26,g48,g37,g15,g24,g34,g13,g12    !sides
      integer ind(ncx,ncy,ncz)    ! unit cell: 1-pore, 0-solid
      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2)

      do k=1,3                    ! extract color field part for calculations
       do j=1,3
        do i=1,3
c         x=mod(ic(1)+ncx+i-3,ncx)+1  ! apply periodic conditions
c         y=mod(ic(2)+ncy+j-3,ncy)+1  ! apply periodic conditions
c         z=mod(ic(3)+ncz+k-3,ncz)+1  ! apply periodic conditions
c         if(mijk(x,y,z)<>0)then
c          c(i,j,k)=cf(mijk(x,y,z))
c         else
c          c(i,j,k)=wet
c         endif
         x=ipcx(ic(1)+i-1)
         y=ipcy(ic(2)+j-1)
         z=ipcz(ic(3)+k-1)
         c(i,j,k)=ind(x,y,z)*
     &   (rr(mijk(x,y,z))+rb(mijk(x,y,z))-wet)+wet
        enddo
       enddo
      enddo

      r11  = c(1,1,1)+c(2,1,1) ! first layer edges
      r12  = c(2,1,1)+c(3,1,1)
      r13  = c(1,2,1)+c(2,2,1)
      r14  = c(2,2,1)+c(3,2,1)
      r15  = c(1,3,1)+c(2,3,1)
      r16  = c(2,3,1)+c(3,3,1)
      r17  = c(1,1,1)+c(1,2,1)
      r18  = c(2,1,1)+c(2,2,1)
      r19  = c(3,1,1)+c(3,2,1)
      r110 = c(1,2,1)+c(1,3,1)
      r111 = c(2,2,1)+c(2,3,1)
      r112 = c(3,2,1)+c(3,3,1)

      r21  = c(1,1,2)+c(2,1,2) ! second layer edges
      r22  = c(2,1,2)+c(3,1,2)
      r23  = c(1,2,2)+c(2,2,2)
      r24  = c(2,2,2)+c(3,2,2)
      r25  = c(1,3,2)+c(2,3,2)
      r26  = c(2,3,2)+c(3,3,2)
      r27  = c(1,1,2)+c(1,2,2)
      r28  = c(2,1,2)+c(2,2,2)
      r29  = c(3,1,2)+c(3,2,2)
      r210 = c(1,2,2)+c(1,3,2)
      r211 = c(2,2,2)+c(2,3,2)
      r212 = c(3,2,2)+c(3,3,2)

      r31  = c(1,1,3)+c(2,1,3) ! third layer edges
      r32  = c(2,1,3)+c(3,1,3)
      r33  = c(1,2,3)+c(2,2,3)
      r34  = c(2,2,3)+c(3,2,3)
      r35  = c(1,3,3)+c(2,3,3)
      r36  = c(2,3,3)+c(3,3,3)
      r37  = c(1,1,3)+c(1,2,3)
      r38  = c(2,1,3)+c(2,2,3)
      r39  = c(3,1,3)+c(3,2,3)
      r310 = c(1,2,3)+c(1,3,3)
      r311 = c(2,2,3)+c(2,3,3)
      r312 = c(3,2,3)+c(3,3,3)

      g12 = r18+r28   !sides
      g13 = r13+r23
      g34 = r111+r211
      g24 = r14+r24

      g15 = r21+r23
      g37 = r23+r25
      g48 = r24+r26
      g26 = r22+r24
      g56 = r28+r38
      g57 = r23+r33
      g78 = r211+r311
      g68 = r24+r34

      nm(1,1)=g12-(r17+r27) ! color field gradients calculation (x)
      nm(2,1)=r19+r29-g12
      nm(3,1)=g34-(r110+r210)
      nm(4,1)=r112+r212-g34
      nm(5,1)=g56-(r27+r37)
      nm(6,1)=r29+r39-g56
      nm(7,1)=g78-(r210+r310)
      nm(8,1)=r212+r312-g78

      nm(1,2)=g13-(r11+r21) ! color field gradients calculation (y)
      nm(2,2)=g24-(r12+r22)
      nm(3,2)=r15+r25-g13
      nm(4,2)=r16+r26-g24
      nm(5,2)=g57-(r21+r31)
      nm(6,2)=g68-(r22+r32)
      nm(7,2)=r25+r35-g57
      nm(8,2)=r26+r36-g68

      nm(1,3)=g15-(r11+r13) ! color field gradients calculation (z)
      nm(2,3)=g26-(r12+r14)
      nm(3,3)=g37-(r13+r15)
      nm(4,3)=g48-(r14+r16)
      nm(5,3)=r31+r33-g15
      nm(6,3)=r32+r34-g26
      nm(7,3)=r33+r35-g37
      nm(8,3)=r34+r36-g48

      Cg(1)=nm(1,1)+nm(2,1)+nm(3,1)+nm(4,1)+
     &       nm(5,1)+nm(6,1)+nm(7,1)+nm(8,1) ! (x) color gradient at (x,y,z)
      Cg(2)=nm(1,2)+nm(2,2)+nm(3,2)+nm(4,2)+
     &       nm(5,2)+nm(6,2)+nm(7,2)+nm(8,2) ! (y)
      Cg(3)=nm(1,3)+nm(2,3)+nm(3,3)+nm(4,3)+
     &       nm(5,3)+nm(6,3)+nm(7,3)+nm(8,3) ! (z)
      Cg=Cg*0.03125D0

c       open(2222,file='GRAD')
c       write(2222,*)'Cg = ',Cg
c       write(2222,*)'c = ',c
c       close(2222)

      if(cf(mijk(ic(1),ic(2),ic(3))).lt.0.D0)then
       Fs = sig*Cg     ! surface tension force
      else
       Fs = (/0.D0,0.D0,0.D0/)
      endif
      return
      end
c___________________________________________________
c     lsm_step - makes one integration step in LSM model 
c___________________________________________________
      subroutine lsm_step(ns,rdat,vdat,dt,adat,icors,
     &                    nbo,bn,bon,bx,vb,
     &                    nna,vn,ang,vx,vv,anf,rsi,afdat,rtime,
     &                    abond,sbond,nthread2,
     &                    lib,lia)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      integer*8 nna,nbo
      real*8    abond(nna),sbond(nbo)
      integer   nthread2            ! = nthread*2   
      integer*8 lib(nthread2+1),lia(nthread2+1)

      integer*4 ns ! number of solid points
      real*8    rdat(3,ns) ! elastic solid points coordinates
      real*8    vdat(3,ns) ! elastic solid points velocity
      real*8    dt ! integration time step
      real*8    adat(3,ns) ! elastic solid points acceleration
      real*8    afdat(3,ns)
      integer*4 icors(3,ns) ! coordinates of the solid points
      real*8    bn(3,9) ! normalized vectors
      integer*4 bon(3,nbo)     ! bonds
      real*8    bx(3,9) ! xn/|rn|
      real*8    vb(3,9) ! bond vectors (real numbers)
      real*8    vn(3,19) ! discrete velocities normalized
      integer*4 ang(6,nna) !angles array
      real*8    vx(3,19) ! xn/|rn|
      real*8    vv(3,19) ! discrete velocities (real numbers)
      real*8    anf(9,48) ! angle plane normal, angular force vectors j k; for angular springs
      real*8    rsi ! inverse of solid body density

      real*8 flin(3) ! linear spring force
      real*8 xnj(3),xrj(3),rnj(3),rtj(3),xnk(3),xrk(3),rnk(3),rtk(3) ! force calculation vectors
      real*8 xn(3),xr(3),rn(3),rt(3) ! vectors in linear spring force calculation
      real*8 dfi ! delta phi, angle change for angular force

! Integrate LSM - velocity Verlet algorithm: Start
! Note: now in LSM dt = 1, as well as in LBM dt = 1, so the relations can be simplified
! Second step: calculate new velocities v_i(t+dt/2)=v_i(t)+a_i(t)dt/2
!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(ns,vdat,adat,dt,afdat)
      do i=1,ns
       vdat(1:3,i)=vdat(1:3,i)+adat(1:3,i)*dt*0.5d0
     &                       +afdat(1:3,i)*dt*0.5d0
      enddo
!$OMP END PARALLEL DO

! First step: calculate new nodes positions r_i(t+dt)=r_i(t)+v_i(t)dt+(a_i(t)dt^2)/2
! First step: calculate new nodes positions r_i(t+dt)=r_i(t)+v_i(t+dt/2)dt

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(ns,rdat,vdat,dt)
      do i=1,ns
       rdat(1:3,i)=rdat(1:3,i)+vdat(1:3,i)*dt
      enddo
!$OMP END PARALLEL DO

! Third step: calculate new force F_i(t+dt)  or , a_i(t+dt)=F_i(t+dt) /M_i
      adat = 0.d0 ! initialize all the forces

!$OMP  PARALLEL DEFAULT(NONE)
!$OMP& PRIVATE(i,l,xn,rn,rt,flin,lstart,lend)
!$OMP& SHARED(nbo,bn,bon,vb,rdat,icors,sbond,adat,lib,nthread2)
!$OMP DO
      do l=1,nthread2,2
       lstart = lib(l)+1
       lend   = lib(l+1)
       do i=lstart,lend ! bonds loop to calculate linear springs force
        xn=bn(1:3,bon(3,i)) ! normalized equilibrium i-j vector
        rn=vb(1:3,bon(3,i)) ! not normalized equilibrium i-j vector
        rt=rdat(1:3,bon(2,i))-rdat(1:3,bon(1,i))+rn ! deformed i-j vector

        flin=sbond(i)*((rt(1)*xn(1)+rt(2)*xn(2)+rt(3)*xn(3))*xn-rn) ! linear spring force
        adat(1:3,bon(1,i))=adat(1:3,bon(1,i))+flin ! force acting on the first end of the bond
        adat(1:3,bon(2,i))=adat(1:3,bon(2,i))-flin ! force acting on the second end of the bond
       enddo
      enddo
!$OMP END DO
!$OMP BARRIER
!$OMP DO
      do l=2,nthread2,2
       lstart = lib(l)+1
       lend   = lib(l+1)
       do i=lstart,lend ! bonds loop to calculate linear springs force
        xn=bn(1:3,bon(3,i)) ! normalized equilibrium i-j vector
        rn=vb(1:3,bon(3,i)) ! not normalized equilibrium i-j vector
        rt=rdat(1:3,bon(2,i))-rdat(1:3,bon(1,i))+rn ! deformed i-j vector

        flin=sbond(i)*((rt(1)*xn(1)+rt(2)*xn(2)+rt(3)*xn(3))*xn-rn) ! linear spring force
        adat(1:3,bon(1,i))=adat(1:3,bon(1,i))+flin ! force acting on the first end of the bond
        adat(1:3,bon(2,i))=adat(1:3,bon(2,i))-flin ! force acting on the second end of the bond
       enddo
      enddo
!$OMP END DO
!$OMP END PARALLEL

!$OMP  PARALLEL DEFAULT(NONE)
!$OMP& PRIVATE(i,xrj,rnj,rtj,xrk,rnk,rtk,dfi,l,lstart,lend)
!$OMP& SHARED(nna,vn,vx,vv,ang,rdat,icors,anf,abond,adat,lia,nthread2)
!$OMP DO
      do l=1,nthread2,2
       lstart = lia(l)+1
       lend   = lia(l+1)
       do i=lstart,lend ! angles loop
        xrj=vx(1:3,ang(4,i)) ! xn/|rn|
        rnj=vv(1:3,ang(4,i)) ! not normalized equilibrium i-j vector
        rtj=rdat(1:3,ang(2,i))-rdat(1:3,ang(1,i))+rnj ! deformed i-j vector

        xrk=vx(1:3,ang(5,i)) ! xn/|rn|
        rnk=vv(1:3,ang(5,i)) ! not normalized equilibrium i-k vector
        rtk=rdat(1:3,ang(3,i))-rdat(1:3,ang(1,i))+rnk ! deformed i-k vector

        dfi=((xrk(2)*rtk(3)-xrk(3)*rtk(2)-xrj(2)*rtj(3)+xrj(3)*rtj(2)) ! angle change delta phi
     & *anf(1,ang(6,i))
     & -(xrk(1)*rtk(3)-xrk(3)*rtk(1)-xrj(1)*rtj(3)+xrj(3)*rtj(1))
     & *anf(2,ang(6,i))
     & +(xrk(1)*rtk(2)-xrk(2)*rtk(1)-xrj(1)*rtj(2)+xrj(2)*rtj(1))
     & *anf(3,ang(6,i)))*abond(i)

        adat(1:3,ang(2,i))=adat(1:3,ang(2,i))+dfi*anf(4:6,ang(6,i)) ! angular force for point j
        adat(1:3,ang(3,i))=adat(1:3,ang(3,i))+dfi*anf(7:9,ang(6,i)) ! angular force for point k
        adat(1:3,ang(1,i))=adat(1:3,ang(1,i))
     & -(dfi*anf(4:6,ang(6,i))+dfi*anf(7:9,ang(6,i)))
       enddo
      enddo
!$OMP END DO
!$OMP BARRIER
!$OMP DO
      do l=2,nthread2,2
       lstart = lia(l)+1
       lend   = lia(l+1)
       do i=lstart,lend ! angles loop
        xrj=vx(1:3,ang(4,i)) ! xn/|rn|
        rnj=vv(1:3,ang(4,i)) ! not normalized equilibrium i-j vector
        rtj=rdat(1:3,ang(2,i))-rdat(1:3,ang(1,i))+rnj ! deformed i-j vector

        xrk=vx(1:3,ang(5,i)) ! xn/|rn|
        rnk=vv(1:3,ang(5,i)) ! not normalized equilibrium i-k vector
        rtk=rdat(1:3,ang(3,i))-rdat(1:3,ang(1,i))+rnk ! deformed i-k vector

        dfi=((xrk(2)*rtk(3)-xrk(3)*rtk(2)-xrj(2)*rtj(3)+xrj(3)*rtj(2)) ! angle change delta phi
     & *anf(1,ang(6,i))
     & -(xrk(1)*rtk(3)-xrk(3)*rtk(1)-xrj(1)*rtj(3)+xrj(3)*rtj(1))
     & *anf(2,ang(6,i))
     & +(xrk(1)*rtk(2)-xrk(2)*rtk(1)-xrj(1)*rtj(2)+xrj(2)*rtj(1))
     & *anf(3,ang(6,i)))*abond(i)

        adat(1:3,ang(2,i))=adat(1:3,ang(2,i))+dfi*anf(4:6,ang(6,i)) ! angular force for point j
        adat(1:3,ang(3,i))=adat(1:3,ang(3,i))+dfi*anf(7:9,ang(6,i)) ! angular force for point k
        adat(1:3,ang(1,i))=adat(1:3,ang(1,i))
     & -(dfi*anf(4:6,ang(6,i))+dfi*anf(7:9,ang(6,i)))
       enddo
      enddo
!$OMP END DO
!$OMP END PARALLEL
      adat = adat*rsi ! calculate acceleration

! Fourth step: calculate new velocities v_i(t+dt)=v_i(t+dt/2)+a_i(t+dt)dt/2

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(ns,adat,vdat)
       do i=1,ns
        adat(1:3,i)=adat(1:3,i)-0.25d0*vdat(1:3,i) ! viscous effects
       enddo
!$OMP END PARALLEL DO

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(ns,vdat,adat,dt,afdat)
      do i=1,ns
       vdat(1:3,i)=vdat(1:3,i)+adat(1:3,i)*dt*0.5d0
     &                       +afdat(1:3,i)*dt*0.5d0
      enddo
!$OMP END PARALLEL DO
c      write(*,*)'rdat',rdat
c      pause
c      write(*,*)'adat',adat
c      pause
c      write(*,*)'vdat',vdat
c      pause

! Integrate LSM - velocity Verlet algorithm: End
      return
      end
c___________________________________________________
c     check_laplace - check Laplace's law
c___________________________________________________
      subroutine check_laplace(nl,rr,rb,cf,cr2,cb2)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 rr(nl)  ! red fluid density field
      real*8 rb(nl)  ! blue fluid density field
      real*8 cf(nl)  ! color field
      real*8 cr2     ! red sound speed
      real*8 cb2     ! blue sound speed
      real*8 Pr,Pr2  ! red fluid pressure mean value
      real*8 Pb,Pb2  ! blue fluid pressure mean value

      integer*4 nr   ! red fluid points number
      integer*4 nb   ! blue points fluid number

      nr=0     ! red fluid points number initialization
      nb=0     ! blue points fluid number initialization
      Pr=0.D0  ! red fluid pressure initialization
      Pb=0.D0  ! blue fluid pressure initialization
      Pr2=0.D0 ! red fluid pressure initialization
      Pb2=0.D0 ! blue fluid pressure initialization

      open(1,file='laplace_check')  ! save results

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(nl,nr,Pr,rr,rb,Pr2,cf,nb,Pb,Pb2)
!$OMP& REDUCTION(+: nr,Pr,Pr2,nb,Pb,Pb2)
      do i=1,nl
       if(cf(i)>0.99999D0) then       ! red fluid pressure calculation
        nr=nr+1                       ! count red fluid points
        Pr=Pr+rr(i)+rb(i)             ! red fluid pressure
        Pr2=Pr2+rr(i)                 ! red fluid pressure
       elseif(cf(i)<-0.99999D0) then  ! blue fluid pressure calculation
        nb=nb+1                       ! count red fluid points
        Pb=Pb+rb(i)+rr(i)             ! red fluid pressure
        Pb2=Pb2+rb(i)                 ! red fluid pressure
       endif
      enddo
!$OMP END PARALLEL DO

      Pr=cr2*Pr/nr     ! red fluid pressure mean value 
      Pb=cb2*Pb/nb     ! blue fluid pressure mean value
      Pr2=cr2*Pr2/nr   ! red fluid pressure mean value
      Pb2=cb2*Pb2/nb   ! blue fluid pressure mean value

      write(1,*)'red fluid mean pressure = ',Pr
      write(1,*)'number of red points = ',nr
      write(1,*)'blue fluid mean pressure = ',Pb
      write(1,*)'number of blue points = ',nb 
      write(1,*)'Pressure drop = ',Pb-Pr
      write(1,*)'red fluid mean pressure = ',Pr2
      write(1,*)'number of red points = ',nr
      write(1,*)'blue fluid mean pressure = ',Pb2
      write(1,*)'number of blue points = ',nb
      write(1,*)'Pressure drop = ',Pb2-Pr2

      close(1)

      return
      end
c___________________________________________________
c     save_results - save run results before program exit
c___________________________________________________
      subroutine save_results(ipcx,ipcy,ipcz,ind,nl,fr,fb,iv,
     &   mijk,ncx,ncy,ncz,icor,sig,cr2,cb2,wet,it1,bfr,bfb
     &   ,itw,rr,rb,cf,rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti,afdat)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      integer*4 ncx               ! x unit cell size
      integer*4 ncy               ! y unit cell size
      integer*4 ncz               ! z unit cell size
      integer*4 mijk(ncx,ncy,ncz) ! liquid points numbers
      integer*4 icor(3,nl)        ! liquid points coordinates
      integer*4 ic(3)             ! interface point coordinates
      integer*4 l                 ! liquid point number

      real*8 u(3)               ! liquid point velocity
      real*8 r                  ! liquid point density (color)
      real*8 ri                 ! interface liquid point density
      real*8 rr(nl)             ! red fluid density field
      real*8 rb(nl)             ! blue fluid density field
      real*8 cf(nl)             ! color field
      real*8 cr2                ! red sound speed
      real*8 cb2                ! blue sound speed
      real*8 wet                ! wettability

      real*8 fr(19,nl)          ! red fluid particle distributions
      real*8 fb(19,nl)          ! blue fluid particle distributions
      real*8 f(19)              ! interface fluid particles distribution
      real*8 iv(3,19)           ! particle velocities
      real*8 bfr(3),bfb(3)      ! 
      real*8 bfi(3)             ! interface body force
      real*8 Fs(3)              ! surface tension force
      real*8 Cg(3)              ! color gradient
      integer ind(ncx,ncy,ncz)    ! unit cell: 1-pore, 0-solid
      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2)
      integer INDSRB(ncx,ncy,ncz) ! phase distribution

      integer*4 ns ! number of solid points
      real*8    rdat(3,ns) ! elastic solid points coordinates
      real*8    vdat(3,ns) ! elastic solid points velocity
      real*8    adat(3,ns) ! elastic solid points acceleration
      real*8    afdat(3,ns)
      integer*4 icors(3,ns) ! coordinates of the solid points
      integer*4 mijks(ncx,ncy,ncz) ! solid points numbers
      real*8    rsi ! inverse of solid body density
      real*8 dt ! time step, time step inverse

c      real*8 c(3,3,3)
c      integer*4 x,y,z
      character*255 red,blue,interfac ! filename variables
      real*8 nb, bcoor(3)             ! number of blue points, center mass coordinate
      character*30 format4444         ! format for pgf95
      character*255 pressuref,displf
c      red='red'
c      blue='blue'
c      interfac='interface'
       pressuref='pressure'
       displf='LSM_disf'
      if(it1.le.9) then
c       write(red(4:4),111)it1
c       write(blue(5:5),111)it1
c       write(interfac(10:10),111)it1
       write(pressuref(9:9),111)it1
       write(displf(9:9),111)it1
      endif
      if(it1.gt.9.and.it1.le.99) then
c       write(red(4:5),222)it1
c       write(blue(5:6),222)it1
c       write(interfac(10:11),222)it1
        write(pressuref(9:10),222)it1
        write(displf(9:10),222)it1
      endif
      if(it1.gt.99.and.it1.le.999) then
c       write(red(4:6),333)it1
c       write(blue(5:7),333)it1
c       write(interfac(10:12),333)it1
       write(pressuref(9:11),333)it1
       write(displf(9:11),333)it1
      endif
      if(it1.gt.999) then
c       write(red(4:7),444)it1
c       write(blue(5:8),444)it1
c       write(interfac(10:13),444)it1
       write(pressuref(9:12),444)it1
       write(displf(9:12),444)it1
      endif

111   format(i1)
222   format(i2)
333   format(i3)
444   format(i4)

      open(1,file='velocity_field')                 ! file to save velocity field
      open(2,file='color_field')                    ! file to save color field
c     open(3,file='Fs')                             ! surface tension force
c      open(4,file=red)                              ! red fluid points
c      open(5,file=blue)                             ! blue fluid
c      open(6,file=interfac)                         ! interface points
      open(7,file=pressuref)                 ! pressure field

      bcoor=(/0.D0,0.D0,0.D0/)  ! blue fluid center mass coordinate
      nb=0.D0                   ! number of blue points
      INDSRB=0                  ! initialize phases distribution

      do k=1,ncz
       do j=1,ncy
        do i=1,ncx
         l=mijk(i,j,k)                             ! liquid point number
         ic=icor(1:3,l)                            ! liquid poin coordinates
         if(l>0) then                              ! calculate fluid velocity and color

          if(cf(l)>0.9D0) then
           INDSRB(i,j,k) = 1   ! rouge pur 
          elseif(cf(l)<-0.9D0) then
           INDSRB(i,j,k) = 2   ! bleu pur
          elseif(cf(l).GE.0.D0.AND.cf(l).LE.0.9D0) then
           INDSRB(i,j,k) = 6   ! rouge un peu bleu
          else
           INDSRB(i,j,k) = 7   ! bleu un peu rouge
          endif

          if(rr(l)>=rb(l)) then                     ! red fluid velocity calculation
           call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &                 ,Cg,Fs,sig,wet) ! surface tension force
c          write(3,*)ic,Fs
           f   = fr(1:19,l)+fb(1:19,l)               ! calculate common particles distribution
           ri  = dti/(rr(l)+rb(l))                  ! 1.D0/fluid density at interface
           bfi = dt*(bfr+Fs)*0.5D0                      ! body force
           u(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11)     ! momentum
     &         +f(12)-f(13)+f(14)-f(15)+bfi(1))*ri

           u(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &         +f(16)-f(17)+f(18)-f(19)+bfi(2))*ri

           u(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &         +f(16)+f(17)-f(18)-f(19)+bfi(3))*ri
c           write(4,*)ic              ! red point

          elseif(rr(l)<rb(l)) then                  ! blue fluid velocity calculation
           call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &                 ,Cg,Fs,sig,wet) ! surface tension force
c          write(3,*)ic,Fs
           f=fr(1:19,l)+fb(1:19,l)                  ! calculate common particles distribution
           ri  = dti/(rr(l)+rb(l))                 ! 1.D0/fluid density at interface
           bfi = dt*(bfr+Fs)*0.5D0                     ! body force
           u(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11)    ! momentum
     &         +f(12)-f(13)+f(14)-f(15)+bfi(1))*ri

           u(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &         +f(16)-f(17)+f(18)-f(19)+bfi(2))*ri

           u(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &         +f(16)+f(17)-f(18)-f(19)+bfi(3))*ri
c           write(5,*)ic              ! blue point
c           bcoor=bcoor+ic ! coordinate for bubble in the pipe test       
c           nb=nb+1.D0

c          else
c           write(6,*)ic   ! interface point
c           write(3,*)ic,Fs
          endif

          r=cf(l)!rr(l)+rb(l)                       ! fluid density or color field
          write(7,*)(rr(l)*cr2+rb(l)*cb2)-cr2*1.D0  ! pressure field
         else
          u=(/0.d0,0.d0,0.d0/)                      ! corresponds to solid
          r=1.2D0                                   ! corresponds to solid
          write(7,*)0.D0
         endif

         write(1,*)u                          ! save velocity
         write(2,*)r                                ! save color

        enddo
       enddo
      enddo

      close(1)
      close(2)
c     close(3)
c      close(4)
c      close(5)
c      close(6)
      close(7)

c      open(1,file='bubble_coordinate',position='append')
c      write(1,*)bcoor/nb
c      close(1)
      write(format4444,*)'(',ncx,'i2)'
      open(1,file='ind_red_blue_bac') ! output of phase distribuion(old program format)
      WRITE(1,4579)it1*itw 
      WRITE(1,*)'a=['
      DO K=1,NCZ
       DO J=1,NCY
        WRITE(1,fmt=format4444)(INDSRB(I,J,K),I=1,NCX)
       ENDDO
      ENDDO
      WRITE(1,*)'];'
      WRITE(1,*)'clm'
      close(1)

      call system('cat ind_red_blue_bac >> ind_red_blue')
      call system('rm ind_red_blue_bac')

c4444    FORMAT(64I2)                   
4579    FORMAT(///,5X,'ITER=',I7,';')

! Save output data: coordinates, displacements, velocities, forces, strain and stress tensors
      open(1,file='LSM_coord_field')
      open(2,file= displf)
      open(3,file='LSM_velocity_field')
      open(4,file='LSM_force_field')
      open(5,file='LSM_icors')
      open(7,file='LSM_fluid_force')

      do k=1,ncz
       do j=1,ncy
        do i=1,ncx
         l=mijks(i,j,k) ! solid point number
         if(l.ne.0.d0)then
          write(1,*)rdat(1:3,l) ! save coordinates
          write(2,*)rdat(1:3,l) ! save displacements
          write(3,*)vdat(1:3,l) ! save velocities
          write(4,*)adat(1:3,l)/rsi ! save forces
          write(5,*)icors(1:3,l) ! icors
          write(7,*)afdat(1:3,l)/rsi
         else
          write(2,*)(/0.d0,0.d0,0.d0/)
          write(3,*)(/0.d0,0.d0,0.d0/)
          write(4,*)(/0.d0,0.d0,0.d0/)
          write(7,*)(/0.d0,0.d0,0.d0/)
         endif
        enddo
       enddo
      enddo

      close(1)
      close(2)
      close(3)
      close(4)
      close(5)
      close(7)
! End saving data
      return
      end
c___________________________________________________
c     collision - calculate particles collision
c     Stokes flow
c___________________________________________________
      subroutine stokes_collision(t1,t2,t3,c1d6,c1d12,
     &  c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &  c5d399,c11d2394,c1d252,c4d1197,
     &  f,pcf,r,Fp,S,dt,dti)
      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 j(3)    ! liquid point momentum
      real*8 f(19)   ! distribution function
      real*8 r       ! fluid point density
      real*8 fe(19)  ! equilibrium distribution function
      real*8 fl(19)  ! difference between real state and equilibrium
      real*8 mo(19)  ! moments used in collision process
      real*8 S(19)   ! relaxation times vector
      real*8 mb(19)  ! postcollision distribution difference vector
      real*8 pcf(19) ! post collision distribution function
      real*8 Fp(19)  ! body force projections
      real*8 j1d6,j2d6,j3d6
      real*8 com1,com2,com3,com4,com5,com6,com7,com8,com9,com10,com11
      real*8 j1p2d12,j1m2d12,j1p3d12,j1m3d12,j2p3d12,j2m3d12

      real*8 t1,t2,t3
      real*8 c1d6,c1d12,c5d399,c19d399
      real*8 c11d2394,c1d63,c1d18,c1d36
      real*8 c4d1197,c1d252,c1d72,c1d24

      real*8 dt,dti ! time step, time step inverse

      j(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11)    ! momentum
     &        +f(12)-f(13)+f(14)-f(15))*dti

      j(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19))*dti

      j(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19))*dti

      fe(1)=r*t1           ! equilibrium state Stokes

      j1d6 = j(1)*c1d6*dt
      j2d6 = j(2)*c1d6*dt
      j3d6 = j(3)*c1d6*dt

      com1 = t2*r

      fe(2)=com1+j1d6
      fe(3)=com1-j1d6
      fe(4)=com1+j2d6
      fe(5)=com1-j2d6
      fe(6)=com1+j3d6
      fe(7)=com1-j3d6

      j1p2d12=(j(1)+j(2))*c1d12*dt
      j1m2d12=(j(1)-j(2))*c1d12*dt
      j1p3d12=(j(1)+j(3))*c1d12*dt
      j1m3d12=(j(1)-j(3))*c1d12*dt
      j2p3d12=(j(2)+j(3))*c1d12*dt
      j2m3d12=(j(2)-j(3))*c1d12*dt

      com2 = t3*r

      fe(8) =com2+j1p2d12
      fe(11)=com2-j1p2d12
      fe(9) =com2-j1m2d12
      fe(10)=com2+j1m2d12

      fe(12)=com2+j1p3d12
      fe(15)=com2-j1p3d12
      fe(14)=com2+j1m3d12
      fe(13)=com2-j1m3d12

      fe(16)=com2+j2p3d12
      fe(19)=com2-j2p3d12
      fe(18)=com2+j2m3d12
      fe(17)=com2-j2m3d12

      do i1=1,19   ! difference between real state and equilibrium
       fl(i1)=f(i1)-fe(i1)
      enddo
      com3 = fl(2)+fl(3)+fl(4)+fl(5)+fl(6)+fl(7)
      com4 = fl(8)+fl(9)+fl(10)+fl(11)+fl(12)+fl(13)+fl(14)+fl(15)
     &       +fl(16)+fl(17)+fl(18)+fl(19)

      mo(1)=0.D0 ! liquid point moments calculation

      mo(2)=-30.D0*fl(1)-11.D0*com3+8.D0*com4

      mo(3)=12.D0*fl(1)-4.D0*com3+com4

      mo(4)=0.D0

      mo(5)=4.D0*(fl(3)-fl(2))+fl(8)-fl(9)+fl(10)-fl(11)+fl(12)
     &      -fl(13)+fl(14)-fl(15)
      mo(6)=0.D0
      mo(7)=4.D0*(fl(5)-fl(4))+fl(8)+fl(9)-fl(10)-fl(11)+fl(16)
     &      -fl(17)+fl(18)-fl(19)
      mo(8)=0.D0
      mo(9)=4.D0*(fl(7)-fl(6))+fl(12)+fl(13)-fl(14)-fl(15)+fl(16)
     &      +fl(17)-fl(18)-fl(19)

      com5 = fl(8)+fl(9)+fl(10)+fl(11)
      com6 = fl(16)+fl(17)+fl(18)+fl(19)
      com7 = fl(12)+fl(13)+fl(14)+fl(15)
      com8 = fl(4)+fl(5)-fl(6)-fl(7)
      com9 = fl(4)+fl(5)+fl(6)+fl(7)

      mo(10)=2.D0*(fl(2)+fl(3)-com6)-com9+com5+com7
      mo(11)=-4.D0*(fl(2)+fl(3))+2.D0*(com9-com6)+com5+com7
      mo(12)=com8+com5-com7
      mo(13)=-2.D0*com8+com5-com7

      mo(14)=fl(8)-fl(9)-fl(10)+fl(11)
      mo(15)=fl(16)-fl(17)-fl(18)+fl(19)
      mo(16)=fl(12)-fl(13)-fl(14)+fl(15)

      mo(17)=fl(8)-fl(9)+fl(10)-fl(11)-fl(12)+fl(13)-fl(14)+fl(15)
      mo(18)=-fl(8)-fl(9)+fl(10)+fl(11)+fl(16)-fl(17)+fl(18)-fl(19)
      mo(19)=fl(12)+fl(13)-fl(14)-fl(15)-fl(16)-fl(17)+fl(18)+fl(19)

      do i1=1,19           ! relaxation in moments space
       mo(i1)=mo(i1)*S(i1)
      enddo

      mb(1)=-c5d399*mo(2)+c19d399*mo(3) ! back to particle distributions

      com10 = -c11d2394*mo(2)-c1d63*mo(3)

      mb(2)=com10-0.1D0*mo(5)+c1d18*(mo(10)-mo(11))

      mb(3)=mb(2)+mo(5)*0.2D0

      mb(4)=com10-0.1D0*mo(7)+c1d36*(mo(11)-mo(10))
     &      +c1d12*(mo(12)-mo(13))

      mb(5)=mb(4)+mo(7)*0.2D0

      mb(6)=com10-0.1D0*mo(9)+c1d36*(mo(11)-mo(10))
     &      +c1d12*(mo(13)-mo(12))

      mb(7)=mb(6)+mo(9)*0.2D0

      com11=c4d1197*mo(2)+c1d252*mo(3)

      mb(8)=com11+(mo(5)+mo(7))*0.025D0
     &      +c1d36*mo(10)+c1d72*mo(11)+c1d12*mo(12)+c1d24*mo(13)
     &      +mo(14)*0.25D0+(mo(17)-mo(18))*0.125D0

      mb(9)=mb(8)-0.05D0*mo(5)-0.5D0*mo(14)-0.25D0*mo(17)

      mb(10)=mb(8)+0.25D0*mo(18)-0.05D0*mo(7)-0.5D0*mo(14)

      mb(11)=mb(10)+0.5D0*mo(14)-0.05D0*mo(5)-0.25D0*mo(17)

      mb(12)=com11+(mo(5)+mo(9))*0.025D0
     &       +c1d36*mo(10)+c1d72*mo(11)-c1d12*mo(12)-c1d24*mo(13)
     &       +mo(16)*0.25D0+(mo(19)-mo(17))*0.125D0

      mb(13)=mb(12)+0.25D0*mo(17)-0.5D0*mo(16)-0.05D0*mo(5)

      mb(14)=mb(12)-0.05D0*mo(9)-0.5D0*mo(16)-0.25D0*mo(19)
      mb(15)=mb(13)+0.5D0*mo(16)-0.05D0*mo(9)-0.25D0*mo(19)

      mb(16)=com11+(mo(7)+mo(9))*0.025D0
     &       -c1d18*mo(10)-c1d36*mo(11)+mo(15)*0.25D0
     &       +(mo(18)-mo(19))*0.125D0

      mb(17)=mb(16)-0.05D0*mo(7)-0.5D0*mo(15)-0.25D0*mo(18)
      mb(18)=mb(16)+0.25D0*mo(19)-0.05D0*mo(9)-0.5D0*mo(15)
      mb(19)=mb(18)+0.5D0*mo(15)-0.05D0*mo(7)-0.25D0*mo(18)

c         pcf(1:19,i)=pf-mb+Fp

c      do i1=1,19   ! postcollision state calculation
c       pcf(i1)=f(i1)-mb(i1)+Fp(i1)
c      enddo
      f(1)=f(1)-mb(1)+Fp(1)
      do i1=2,19   ! postcollision state calculation
       pcf(i1)=f(i1)-mb(i1)+Fp(i1)
      enddo

      return
      end
c___________________________________________________
c     collision - calculate particles collision
c     Navier-Stokes equation
c___________________________________________________
      subroutine collision(t1,t2,t3,c1d6,c1d12,
     &  c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &  c5d399,c11d2394,c1d252,c4d1197,
     &  f,pcf,r,bf,Fp,S,dt,dti,dt2)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 j(3)    ! liquid point momentum
      real*8 f(19)   ! distribution function
      real*8 r       ! fluid point density
      real*8 bf(3)   ! body force
      real*8 u(3)    ! liquid point velocity
      real*8 u2      ! velocity norm square
      real*8 fe(19)  ! equilibrium distribution function
      real*8 fl(19)  ! difference between real state and equilibrium 
      real*8 mo(19)  ! moments used in collision process
      real*8 S(19)   ! relaxation times vector
      real*8 mb(19)  ! postcollision distribution difference vector
      real*8 pcf(19) ! post collision distribution function
      real*8 Fp(19)  ! body force projections
      real*8 u1x2,u2x2,u3x2
      real*8 j1d6,j2d6,j3d6
      real*8 rd4
      real*8 fe1,fe2,fe3
      real*8 com1,com2,com3,com4,com5,com6,com7,com8,com9,com10,com11 
      real*8 j1p2d12,j1m2d12,j1p3d12,j1m3d12,j2p3d12,j2m3d12
      real*8 u1pu2x2,u1mu2x2,u1pu3x2,u1mu3x2,u2pu3x2,u2mu3x2
      real*8 rd8

      real*8 t1,t2,t3
      real*8 c1d6,c1d12,c5d399,c19d399
      real*8 c11d2394,c1d63,c1d18,c1d36
      real*8 c4d1197,c1d252,c1d72,c1d24
      real*8 dr1
      real*8 dt,dti,dt2 ! time step, time step inverse, time step square

      j(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11) ! momentum
     &        +f(12)-f(13)+f(14)-f(15))*dti

      j(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19))*dti

      j(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19))*dti

      dr1 = 1.D0/r
      u(1)=(j(1)+bf(1)*0.5D0*dt)*dr1 ! velocity
      u(2)=(j(2)+bf(2)*0.5D0*dt)*dr1
      u(3)=(j(3)+bf(3)*0.5D0*dt)*dr1

      u1x2 = u(1)*u(1)
      u2x2 = u(2)*u(2)
      u3x2 = u(3)*u(3)

      u2=(u1x2+u2x2+u3x2)*0.5D0 ! (velocity norm square)/2

      fe(1)=r*(t1-u2*dt2)           ! equilibrium state (Navier-Stokes)

      j1d6 = j(1)*c1d6*dt
      j2d6 = j(2)*c1d6*dt
      j3d6 = j(3)*c1d6*dt
      rd4  = r*0.25D0*dt2
      com1 = (t2-u2*c1d6*dt2)*r
      fe1  = com1+rd4*u1x2
      fe2  = com1+rd4*u2x2
      fe3  = com1+rd4*u3x2

      fe(2)=fe1+j1d6
      fe(3)=fe1-j1d6
      fe(4)=fe2+j2d6
      fe(5)=fe2-j2d6
      fe(6)=fe3+j3d6
      fe(7)=fe3-j3d6

      j1p2d12=(j(1)+j(2))*c1d12*dt
      j1m2d12=(j(1)-j(2))*c1d12*dt
      j1p3d12=(j(1)+j(3))*c1d12*dt
      j1m3d12=(j(1)-j(3))*c1d12*dt
      j2p3d12=(j(2)+j(3))*c1d12*dt
      j2m3d12=(j(2)-j(3))*c1d12*dt

      rd8  = r*0.125D0*dt2
      u1pu2x2=rd8*(u(1)+u(2))*(u(1)+u(2))
      u1mu2x2=rd8*(u(1)-u(2))*(u(1)-u(2))
      u1pu3x2=rd8*(u(1)+u(3))*(u(1)+u(3))
      u1mu3x2=rd8*(u(1)-u(3))*(u(1)-u(3))
      u2pu3x2=rd8*(u(2)+u(3))*(u(2)+u(3))
      u2mu3x2=rd8*(u(2)-u(3))*(u(2)-u(3))

      com2 = (t3-u2*c1d12*dt2)*r

      fe(8) =com2+j1p2d12+u1pu2x2
      fe(11)=com2-j1p2d12+u1pu2x2
      fe(9) =com2-j1m2d12+u1mu2x2
      fe(10)=com2+j1m2d12+u1mu2x2

      fe(12)=com2+j1p3d12+u1pu3x2
      fe(15)=com2-j1p3d12+u1pu3x2
      fe(14)=com2+j1m3d12+u1mu3x2
      fe(13)=com2-j1m3d12+u1mu3x2

      fe(16)=com2+j2p3d12+u2pu3x2
      fe(19)=com2-j2p3d12+u2pu3x2
      fe(18)=com2+j2m3d12+u2mu3x2
      fe(17)=com2-j2m3d12+u2mu3x2

      do i1=1,19   ! difference between real state and equilibrium
       fl(i1)=f(i1)-fe(i1)
      enddo
      com3 = fl(2)+fl(3)+fl(4)+fl(5)+fl(6)+fl(7)
      com4 = fl(8)+fl(9)+fl(10)+fl(11)+fl(12)+fl(13)+fl(14)+fl(15)
     &       +fl(16)+fl(17)+fl(18)+fl(19)

      mo(1)=0.D0 ! liquid point moments calculation

      mo(2)=-30.D0*fl(1)-11.D0*com3+8.D0*com4

      mo(3)=12.D0*fl(1)-4.D0*com3+com4

      mo(4)=0.D0

      mo(5)=4.D0*(fl(3)-fl(2))+fl(8)-fl(9)+fl(10)-fl(11)+fl(12)
     &      -fl(13)+fl(14)-fl(15)
      mo(6)=0.D0
      mo(7)=4.D0*(fl(5)-fl(4))+fl(8)+fl(9)-fl(10)-fl(11)+fl(16)
     &      -fl(17)+fl(18)-fl(19)
      mo(8)=0.D0
      mo(9)=4.D0*(fl(7)-fl(6))+fl(12)+fl(13)-fl(14)-fl(15)+fl(16)
     &      +fl(17)-fl(18)-fl(19)

      com5 = fl(8)+fl(9)+fl(10)+fl(11)
      com6 = fl(16)+fl(17)+fl(18)+fl(19)
      com7 = fl(12)+fl(13)+fl(14)+fl(15)
      com8 = fl(4)+fl(5)-fl(6)-fl(7)
      com9 = fl(4)+fl(5)+fl(6)+fl(7)

      mo(10)=2.D0*(fl(2)+fl(3)-com6)-com9+com5+com7
      mo(11)=-4.D0*(fl(2)+fl(3))+2.D0*(com9-com6)+com5+com7
      mo(12)=com8+com5-com7
      mo(13)=-2.D0*com8+com5-com7

      mo(14)=fl(8)-fl(9)-fl(10)+fl(11)
      mo(15)=fl(16)-fl(17)-fl(18)+fl(19)
      mo(16)=fl(12)-fl(13)-fl(14)+fl(15)

      mo(17)=fl(8)-fl(9)+fl(10)-fl(11)-fl(12)+fl(13)-fl(14)+fl(15)
      mo(18)=-fl(8)-fl(9)+fl(10)+fl(11)+fl(16)-fl(17)+fl(18)-fl(19)
      mo(19)=fl(12)+fl(13)-fl(14)-fl(15)-fl(16)-fl(17)+fl(18)+fl(19)

      do i1=1,19           ! relaxation in moments space
       mo(i1)=mo(i1)*S(i1)
      enddo


      mb(1)=-c5d399*mo(2)+c19d399*mo(3) ! back to particle distributions

      com10 = -c11d2394*mo(2)-c1d63*mo(3)

      mb(2)=com10-0.1D0*mo(5)+c1d18*(mo(10)-mo(11))

      mb(3)=mb(2)+mo(5)*0.2D0

      mb(4)=com10-0.1D0*mo(7)+c1d36*(mo(11)-mo(10))
     &      +c1d12*(mo(12)-mo(13))

      mb(5)=mb(4)+mo(7)*0.2D0

      mb(6)=com10-0.1D0*mo(9)+c1d36*(mo(11)-mo(10))
     &      +c1d12*(mo(13)-mo(12))

      mb(7)=mb(6)+mo(9)*0.2D0

      com11=c4d1197*mo(2)+c1d252*mo(3)

      mb(8)=com11+(mo(5)+mo(7))*0.025D0
     &      +c1d36*mo(10)+c1d72*mo(11)+c1d12*mo(12)+c1d24*mo(13)
     &      +mo(14)*0.25D0+(mo(17)-mo(18))*0.125D0

      mb(9)=mb(8)-0.05D0*mo(5)-0.5D0*mo(14)-0.25D0*mo(17)

      mb(10)=mb(8)+0.25D0*mo(18)-0.05D0*mo(7)-0.5D0*mo(14)

      mb(11)=mb(10)+0.5D0*mo(14)-0.05D0*mo(5)-0.25D0*mo(17)

      mb(12)=com11+(mo(5)+mo(9))*0.025D0
     &       +c1d36*mo(10)+c1d72*mo(11)-c1d12*mo(12)-c1d24*mo(13)
     &       +mo(16)*0.25D0+(mo(19)-mo(17))*0.125D0

      mb(13)=mb(12)+0.25D0*mo(17)-0.5D0*mo(16)-0.05D0*mo(5)

      mb(14)=mb(12)-0.05D0*mo(9)-0.5D0*mo(16)-0.25D0*mo(19)
      mb(15)=mb(13)+0.5D0*mo(16)-0.05D0*mo(9)-0.25D0*mo(19)

      mb(16)=com11+(mo(7)+mo(9))*0.025D0
     &       -c1d18*mo(10)-c1d36*mo(11)+mo(15)*0.25D0
     &       +(mo(18)-mo(19))*0.125D0

      mb(17)=mb(16)-0.05D0*mo(7)-0.5D0*mo(15)-0.25D0*mo(18)
      mb(18)=mb(16)+0.25D0*mo(19)-0.05D0*mo(9)-0.5D0*mo(15)
      mb(19)=mb(18)+0.5D0*mo(15)-0.05D0*mo(7)-0.25D0*mo(18)

c         pcf(1:19,i)=pf-mb+Fp

c      do i1=1,19   ! postcollision state calculation
c       pcf(i1)=f(i1)-mb(i1)+Fp(i1)
c      enddo
      f(1)=f(1)-mb(1)+Fp(1)
      do i1=2,19   ! postcollision state calculation
       pcf(i1)=f(i1)-mb(i1)+Fp(i1)
      enddo

      return
      end
c___________________________________________________
c     calcFs - surface tension force calculation
c     calculate surface tension force Fs in (x,y,z)
c     interface point 
c___________________________________________________
      subroutine calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz
     &                 ,cf,nl,ic,Cg,Fs,sig,wet)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      integer*4 ncx               ! x unit cell size
      integer*4 ncy               ! y unit cell size
      integer*4 ncz               ! z unit cell size
      integer*4 mijk(ncx,ncy,ncz) ! liquid points numbers
      integer*4 ic(3)             ! interface point coordinates
      integer*4 x,y,z             ! liquid point coordinates

      real*8 cf(nl)               ! color field      
      real*8 Cg(3)                ! color gradient
      real*8 Fs(3)                ! surface tension force
      real*8 sig                  ! surface tension force parameter
      real*8 wet                  ! wettability parameter

      real*8 c(1:3,1:3,1:3)       ! color field part
      real*8 nm(1:8,1:3)          ! color field gradients in 8 intermediate points
      real*8 mm(8)                ! color field gradients modulus in 8 intermediate points
      real*8 norm,normc           ! vector norm
      real*8 dn(3)                ! color field gradient gradient
      real*8 dm(3)                ! color field gradient gradient modulus 
      real*8 k1,k2                ! curvature components
      real*8 r11,r12,r13,r14,r15,r16,r17,r18,r19,r110,r111,r112 !edges
      real*8 r21,r22,r23,r24,r25,r26,r27,r28,r29,r210,r211,r212
      real*8 r31,r32,r33,r34,r35,r36,r37,r38,r39,r310,r311,r312
      real*8 g68,g78,g57,g56,g26,g48,g37,g15,g24,g34,g13,g12    !sides
      integer ind(ncx,ncy,ncz)    ! unit cell: 1-pore, 0-solid
      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2)

      do k=1,3                    ! extract color field part for calculations
       do j=1,3
        do i=1,3
c         x=mod(ic(1)+ncx+i-3,ncx)+1  ! apply periodic conditions
c         y=mod(ic(2)+ncy+j-3,ncy)+1  ! apply periodic conditions
c         z=mod(ic(3)+ncz+k-3,ncz)+1  ! apply periodic conditions
c         if(mijk(x,y,z)<>0)then
c          c(i,j,k)=cf(mijk(x,y,z))
c         else
c          c(i,j,k)=wet
c         endif
         x=ipcx(ic(1)+i-1)
         y=ipcy(ic(2)+j-1)
         z=ipcz(ic(3)+k-1)
         c(i,j,k)=ind(x,y,z)*(cf(mijk(x,y,z))-wet)+wet
        enddo
       enddo
      enddo

      r11  = c(1,1,1)+c(2,1,1) ! first layer edges
      r12  = c(2,1,1)+c(3,1,1)
      r13  = c(1,2,1)+c(2,2,1)
      r14  = c(2,2,1)+c(3,2,1)
      r15  = c(1,3,1)+c(2,3,1)
      r16  = c(2,3,1)+c(3,3,1)
      r17  = c(1,1,1)+c(1,2,1)
      r18  = c(2,1,1)+c(2,2,1)
      r19  = c(3,1,1)+c(3,2,1)
      r110 = c(1,2,1)+c(1,3,1)
      r111 = c(2,2,1)+c(2,3,1)
      r112 = c(3,2,1)+c(3,3,1)

      r21  = c(1,1,2)+c(2,1,2) ! second layer edges
      r22  = c(2,1,2)+c(3,1,2)
      r23  = c(1,2,2)+c(2,2,2)
      r24  = c(2,2,2)+c(3,2,2)
      r25  = c(1,3,2)+c(2,3,2)
      r26  = c(2,3,2)+c(3,3,2)
      r27  = c(1,1,2)+c(1,2,2)
      r28  = c(2,1,2)+c(2,2,2)
      r29  = c(3,1,2)+c(3,2,2)
      r210 = c(1,2,2)+c(1,3,2)
      r211 = c(2,2,2)+c(2,3,2)
      r212 = c(3,2,2)+c(3,3,2)

      r31  = c(1,1,3)+c(2,1,3) ! third layer edges
      r32  = c(2,1,3)+c(3,1,3)
      r33  = c(1,2,3)+c(2,2,3)
      r34  = c(2,2,3)+c(3,2,3)
      r35  = c(1,3,3)+c(2,3,3)
      r36  = c(2,3,3)+c(3,3,3)
      r37  = c(1,1,3)+c(1,2,3)
      r38  = c(2,1,3)+c(2,2,3)
      r39  = c(3,1,3)+c(3,2,3)
      r310 = c(1,2,3)+c(1,3,3)
      r311 = c(2,2,3)+c(2,3,3)
      r312 = c(3,2,3)+c(3,3,3)

      g12 = r18+r28   !sides
      g13 = r13+r23
      g34 = r111+r211
      g24 = r14+r24

      g15 = r21+r23
      g37 = r23+r25
      g48 = r24+r26
      g26 = r22+r24

      g56 = r28+r38
      g57 = r23+r33
      g78 = r211+r311
      g68 = r24+r34

      nm(1,1)=g12-(r17+r27) ! color field gradients calculation (x)
      nm(2,1)=r19+r29-g12
      nm(3,1)=g34-(r110+r210)
      nm(4,1)=r112+r212-g34
      nm(5,1)=g56-(r27+r37)
      nm(6,1)=r29+r39-g56
      nm(7,1)=g78-(r210+r310)
      nm(8,1)=r212+r312-g78

      nm(1,2)=g13-(r11+r21) ! color field gradients calculation (y)
      nm(2,2)=g24-(r12+r22)
      nm(3,2)=r15+r25-g13
      nm(4,2)=r16+r26-g24
      nm(5,2)=g57-(r21+r31)
      nm(6,2)=g68-(r22+r32)
      nm(7,2)=r25+r35-g57
      nm(8,2)=r26+r36-g68

      nm(1,3)=g15-(r11+r13) ! color field gradients calculation (z)
      nm(2,3)=g26-(r12+r14)
      nm(3,3)=g37-(r13+r15)
      nm(4,3)=g48-(r14+r16)
      nm(5,3)=r31+r33-g15
      nm(6,3)=r32+r34-g26
      nm(7,3)=r33+r35-g37
      nm(8,3)=r34+r36-g48

      Cg(1)=nm(1,1)+nm(2,1)+nm(3,1)+nm(4,1)+
     &       nm(5,1)+nm(6,1)+nm(7,1)+nm(8,1) ! (x) color gradient at (x,y,z)
      Cg(2)=nm(1,2)+nm(2,2)+nm(3,2)+nm(4,2)+
     &       nm(5,2)+nm(6,2)+nm(7,2)+nm(8,2) ! (y)
      Cg(3)=nm(1,3)+nm(2,3)+nm(3,3)+nm(4,3)+
     &       nm(5,3)+nm(6,3)+nm(7,3)+nm(8,3) ! (z)
      normc=sqrt(Cg(1)*Cg(1)+Cg(2)*Cg(2)+Cg(3)*Cg(3))

      dn(1)=nm(2,1)+nm(4,1)+nm(6,1)+nm(8,1)  ! gradient of the color gradient
     &      -nm(1,1)-nm(3,1)-nm(5,1)-nm(7,1) ! x gradient
      dn(2)=nm(4,2)+nm(8,2)+nm(3,2)+nm(7,2)
     &      -nm(1,2)-nm(2,2)-nm(5,2)-nm(6,2) ! y
      dn(3)=nm(5,3)+nm(6,3)+nm(7,3)+nm(8,3)
     &      -nm(1,3)-nm(2,3)-nm(3,3)-nm(4,3) ! z

      k1=dn(1)+dn(2)+dn(3)

      do i=1,8                                      ! norms
       mm(i)=sqrt(nm(i,1)*nm(i,1)+nm(i,2)*nm(i,2)+nm(i,3)*nm(i,3))
      enddo
     
      dm(1)=mm(2)+mm(4)+mm(6)+mm(8)
     &      -mm(1)-mm(3)-mm(5)-mm(7) ! x gradient
      dm(2)=mm(4)+mm(8)+mm(3)+mm(7)
     &      -mm(1)-mm(2)-mm(5)-mm(6) ! y
      dm(3)=mm(5)+mm(6)+mm(7)+mm(8)
     &      -mm(1)-mm(2)-mm(3)-mm(4) ! z

      k2=Cg(1)*dm(1)+Cg(2)*dm(2)+Cg(3)*dm(3)
      if (normc<>0.D0) then
       k2=k2/normc
       Cg=Cg/normc
      endif

      Fs=sig*(k2-k1)*Cg ! surface tension force

      return 
      end
c___________________________________________________
c     initdistr - initialize distribution functions
c___________________________________________________
      subroutine initdistr(fr,fb,nl,rr0,rb0,tr,tb,icon,itms,sat) 

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 fr(19,nl)      ! red particle populations
      real*8 fb(19,nl)      ! blue particle populations 
      real*8 cfield(nl)     ! color field: 1 -  red, 0 - blue, 0 < interface < 1 
      real*8 rr0            ! red fluid density
      real*8 rb0            ! blue fluid density
      real*8 tr(19)         ! red lattice constants
      real*8 tb(19)         ! blue lattice constants
      integer itms          ! outer loop start indices

      real*8 sat                   ! blue fluid saturation
      real*8 seed                  ! seed
      real*8 rn                    ! random number

      DATA D2P31M/2147483647.D0/        
      DATA D2P31 /2147483648.D0/
      seed=13.081984D0
 
      if (icon==0) then ! initialize randomly

       do i=1,nl                          ! set blue fluid sphere in the unit cell
        seed = DMOD(16807.D0*seed,D2P31M) ! generate random number
        rn   = seed/D2P31
        if(rn.le.sat)then
         cfield(i)=0.D0 ! blue fluid
        else
         cfield(i)=1.D0 ! red fluid
        endif
       enddo


!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(nl,fr,tr,cfield,rr0,fb,tb,rb0)
       do i=1,nl                        ! initialize particle populations with equilibrium state
        fr(1:19,i)=tr*cfield(i)*rr0
        fb(1:19,i)=tb*(1.D0-cfield(i))*rb0
       enddo
!$OMP END PARALLEL DO
       itms = 1

      elseif (icon==1) then             ! read data from archiv
       open(1,file='iteration2')
       read(1,*)itms
       read(1,*)((fr(j,i),j=1,19),i=1,nl)
       read(1,*)((fb(j,i),j=1,19),i=1,nl)
       itms=itms+1
      endif

      return 
      end
c___________________________________________________
c     collmatrTRT - create TRT collision vector 
c___________________________________________________
      subroutine collmatrTRT(sv,S)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 sv,se,sep,sp,sq,sm    ! collision eigenvalues
      real*8 S(19)                 ! relaxation matrix in moment space 

      se=sv                        ! TRT model eigen values
      sep=sv
      sp=sv
      sq=8.D0*(2.D0-sv)/(8.D0-sv)
      sm=8.D0*(2.D0-sv)/(8.D0-sv)

      S(1)=0.0D0                 ! relaxation parameters in moment space
      S(2)=se
      S(3)=sep
      S(4)=0.0D0
      S(5)=sq
      S(6)=0.0D0
      S(7)=sq
      S(8)=0.0D0
      S(9)=sq
      S(10)=sv
      S(11)=sp
      S(12)=sv
      S(13)=sp
      S(14)=sv
      S(15)=sv
      S(16)=sv
      S(17)=sm
      S(18)=sm
      S(19)=sm

      return
      end
c___________________________________________________
c     check_state - check the state of the running program
c     and calculate some important flow characteristics
c___________________________________________________
      subroutine check_state(ipcx,ipcy,ipcz,ind,it1,fr,fb,nl,rr0,rb0,
     &          eps,ncx,ncy,ncz,istop,lsize,mijk,
     &  vir,vib,idir,t0,icor,sig,iv,cr2,cb2,wet,bfr,bfb,
     &  itw,rr,rb,cf,permro,permbo,
     &  rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti) 
 
      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 permro,permbo        ! old values of relative permeabilities

      integer*4 ncx               ! x unit cell size
      integer*4 ncy               ! y unit cell size
      integer*4 ncz               ! z unit cell size
      integer*4 mijk(ncx,ncy,ncz) ! liquid points numbers

      real*8 diff               ! parameter for convergence test
      real*8 um(3)              ! mean flow velocity
      real*8 u(3)               ! liquid point velocity
      real*8 ri                 ! interface liquid point density
      real*8 rr(nl)             ! red fluid density field
      real*8 rb(nl)             ! blue fluid density field
      real*8 cf(nl)             ! color field
      real*8 Re                 ! Reynolds number
      real*8 Mach               ! Mach number
      real*8 permn              ! permeability
      real*8 t0                 ! unit cell volume
      real*8 cr2                ! red fluid sound speed 
      real*8 cb2                ! blue fluid sound speed
      real*8 ci2                ! interface sound speed
      real*8 wet                ! wettability

      real*8 fr(19,nl)          ! red fluid particle distributions
      real*8 fb(19,nl)          ! blue fluid particle distributions
      real*8 f(19)              ! interface fluid particles distribution
      real*8 iv(3,19)           ! particle velocities
      real*8 bfr(3),bfb(3)      ! red, blue body force
      real*8 bfi(3)             ! interface body force
      real*8 Fs(3)              ! surface tension force
      real*8 sig                ! surface tension force parameter
      real*8 Cg(3)              ! color gradient
      real*8 vir                 ! fluid viscosity
      real*8 vib                ! blue fluid viscosity
      real*8 vi                 ! interface fluid viscosity
      real*8 lsize              ! linear size for Reynolds number
      real*8 tm                 ! total fluid mass
      real*8 svr,svb            ! relaxation parameters
  
      integer*4 ic(3)           ! interface point coordinates 
      integer*4 icor(3,nl)      ! liquid points coordinates
      integer isneg             ! test for negative populations

      real*8 umr(3),umb(3),umi(3) ! average velocities
      real*8 nr,nb,ni             ! point quantities
      real*8 permr,permb,permi    ! permeabilities
      real*8 tmr,tmb              ! total red and blue masses 
      real*8 Qr(3),Qb(3),Qi(3)    ! red and blue flowrates
      real*8 tfr(3),tfb(3),tfi(3) ! total forcesin fluids 
      real*8 brt,bmt(3),bmt1(3)   ! to calculate mass average velocity
      real*8 rmt(3)
      integer ind(ncx,ncy,ncz)    ! unit cell: 1-pore, 0-solid
      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2) ! prediodic boundary conditions
      real*8 jm(3)                ! momentum
      real*8 Cpr,Cpb              ! capillary pressure

      integer*4 ns ! number of solid points
      real*8    rdat(3,ns) ! elastic solid points coordinates
      real*8    vdat(3,ns) ! elastic solid points velocity
      real*8    adat(3,ns) ! elastic solid points acceleration
      integer*4 icors(3,ns) ! coordinates of the solid points
      integer*4 mijks(ncx,ncy,ncz) ! solid points numbers
      real*8    rsi ! inverse of solid body density
      real*8 vstot(3),fstot(3) ! total solid velocity and force
      real*8 cstot(3) ! mean solid coordinate
      real*8 dt,dti ! time step, time step inverse

      vstot=(/0.D0,0.D0,0.D0/)
      fstot=(/0.D0,0.D0,0.D0/)
      cstot=(/0.D0,0.D0,0.D0/)
      Cpr   = 0.D0
      Cpb   = 0.D0
      permn = 0.D0               ! permeability initialization
      diff  = 0.D0               ! convergence variable initialization
      um    = (/0.D0,0.D0,0.D0/) ! fluid mean velocity  initialization
      isneg = 0                  ! test for negative populations
      tm    = 0.D0               ! total fluid mass initialization
      umr   = (/0.D0,0.D0,0.D0/) ! total red velocity
      umb   = (/0.D0,0.D0,0.D0/) ! total blue velcity
      umi   = (/0.D0,0.D0,0.D0/) ! total interface velocity
      nr    = 0.D0               ! number of red points
      nb    = 0.D0               ! number of blue points
      ni    = 0.D0               ! number of interface points
      permr = 0.D0               ! red permeability
      permb = 0.D0               ! blue permeability
      permi = 0.D0               ! interface permeability
      tmr   = 0.D0               ! total red mass
      tmb   = 0.D0               ! total blue mass
      Qr    = (/0.D0,0.D0,0.D0/) ! total red momentum
      Qb    = (/0.D0,0.D0,0.D0/) ! total blue momentum
      Qi    = (/0.D0,0.D0,0.D0/) ! total interface momentum
      tfr   = (/0.D0,0.D0,0.D0/) ! total red force
      tfb   = (/0.D0,0.D0,0.D0/) ! total blue  force
      tfi   = (/0.D0,0.D0,0.D0/) ! total interface force
      bmt1  = (/0.D0,0.D0,0.D0/) ! blue fluid momentum
      bmt   = (/0.D0,0.D0,0.D0/) ! truncated blue fluid momentum
      rmt   = (/0.D0,0.D0,0.D0/)
      brt   = 0.D0               ! truncated blue fluid mass

      svr=1.D0/(vir/cr2+0.5D0)   ! red viscosity related parameter
      svb=1.D0/(vib/cb2+0.5D0)   ! blue viscosity related parameter

      open(17,file='check_state_19',position='append') ! save results in file

      write(17,*)'--------------------'
      write(17,*)'Iteration it1 = ',it1

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i)
!$OMP& SHARED(nl,rr,rb,tmr,tmb,tm,cf,Cpr,Cpb,nr,nb)
!$OMP& REDUCTION(+: tmr,tmb,tm,Cpr,Cpb,nr,nb)
      do i=1,nl                           ! calculate color and density fields and interface
       tmr = tmr+rr(i)                    ! total red mass
       tmb = tmb+rb(i)                    ! total blue mass
       tm  = tm+rr(i)+rb(i)               ! total fluid mass

       if(cf(i)>0.99D0) then          ! red fluid pressure calculation
        nr = nr+1.D0                  ! count red fluid points
        Cpr= Cpr+rr(i)                ! red fluid pressure
       elseif(cf(i)<-0.99D0) then     ! blue fluid pressure calculation
        nb  = nb+1.D0                 ! count red fluid points
        Cpb = Cpb+rb(i)               ! red fluid pressure
       endif
      enddo
!$OMP END PARALLEL DO
      Cpr = cr2*Cpr/nr
      Cpb = cb2*Cpb/nb

      nr    = 0.D0               ! number of red points
      nb    = 0.D0               ! number of blue points

      do i=1,nl                  ! check loop

       do j=1,19
        if(fb(j,i)<0.D0.or.fr(j,i)<0.D0) then   ! test for negative populations
         isneg=1
c         write(17,*)'n. p. ic=',icor(1:3,i),'i = ',i,'j = ',j
c         write(17,*)'fb=',fb(i,1:19)
c         write(17,*)'fr=',fr(i,1:19)
c         write(17,*)'there are negative populations'
        endif
       enddo

       if(rr(i)<0.D0)then
c        write(17,*)'it1 = ',it1,'b ic=',icor(1:3,i),'i = ',i
c        write(17,*)'fr(i,1:19) =',fr(i,1:19)
        write(17,*)'there are negative density red points'
       endif

       if(rb(i)<0.D0)then
c        write(17,*)'it1 = ',it1,'r ic=',icor(1:3,i),'i = ',i
c        write(17,*)'fb(i,1:19) = ',fb(i,1:19)
         write(17,*)'there are negative density blue points'
       endif

!_________________________ this part is only valid for bubbles rising in the pipe test 
        f = fb(1:19,i)
        jm(1)= f(2)-f(3)+f(8)-f(9)+f(10)-f(11)               ! momentum
     &        +f(12)-f(13)+f(14)-f(15)*dti
        jm(2)= f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19)*dti
        jm(3)= f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19)*dti

        bmt=bmt+jm            ! total blue momentum, only blue particles are used

c        bmt1=bmt1+jm            ! total blue momentum, only blue particles are used
c       if(rb(i)>0.1D0)then      ! truncated
c        brt=brt+rb(i)           ! mass
c        bmt=bmt+jm              ! momentum
c       endif

        f = fr(1:19,i)
        jm(1)= f(2)-f(3)+f(8)-f(9)+f(10)-f(11)               ! momentum
     &        +f(12)-f(13)+f(14)-f(15)*dti
        jm(2)= f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19)*dti
        jm(3)= f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19)*dti

        rmt=rmt+jm 
!_________________________

       if(rr(i)>=rb(i)) then
        ic=icor(1:3,i)                                        ! point coordinates
        call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &             ,Cg,Fs,sig,wet)                            ! surface tension force
        f    = fr(1:19,i)+fb(1:19,i)                          ! distribution function
        ri   = 1.D0/(rr(i)+rb(i))                             ! 1.D0/interface point density
        bfi  = dt*(bfr+Fs)*0.5D0                                 ! body force
        jm(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11)                ! momentum
     &        +f(12)-f(13)+f(14)-f(15)+bfi(1))*dti
        jm(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19)+bfi(2))*dti
        jm(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19)+bfi(3))*dti

        Qr  = Qr+jm      ! total red momentum
        um  = um+jm*ri   ! total fluid velocity         
        umr = umr+jm*ri  ! total red  velocity
        nr  = nr+1       ! number of red points
        tfr = tfr+bfi    ! total red force
       elseif(rr(i)<rb(i)) then
        ic=icor(1:3,i)                                       ! interface point coordinates
        call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &       ,Cg,Fs,sig,wet)                                 ! surface tension force
        f=fr(1:19,i)+fb(1:19,i)                              ! distribution function
        ri  = 1.D0/(rr(i)+rb(i))                             ! 1.D0/interface point density
        bfi = dt*(bfb+Fs)*0.5D0                                 ! body force
        jm(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11)               ! momentum
     &        +f(12)-f(13)+f(14)-f(15)+bfi(1))*dti
        jm(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19)+bfi(2))*dti
        jm(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19)+bfi(3))*dti
        Qb  = Qb+jm         ! total blue momentum
        um  = um+jm*ri      ! total fluid velocity
        umb = umb+jm*ri     ! total blue velocity
        nb  = nb+1          ! number of blue points
        tfb = tfb+bfi       ! total blue force
       else           !!! this part is not used !!!
        ic=icor(1:3,i)                                       ! interface point coordinates
        call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &             ,Cg,Fs,sig,wet)                           ! surface tension force
        f=fr(i,1:19)+fb(i,1:19)                              ! distribution function
        ri  = 1.D0/(rr(i)+rb(i))                             ! 1.D0/interface point density
        bfi = dt*((bfr*rr(i)+bfb*rb(i))*ri+Fs)*0.5D0            ! body force
        jm(1)=(f(2)-f(3)+f(8)-f(9)+f(10)-f(11)               ! momentum
     &        +f(12)-f(13)+f(14)-f(15)+bfi(1))*dti
        jm(2)=(f(4)-f(5)+f(8)+f(9)-f(10)-f(11)
     &        +f(16)-f(17)+f(18)-f(19)+bfi(2))*dti
        jm(3)=(f(6)-f(7)+f(12)+f(13)-f(14)-f(15)
     &        +f(16)+f(17)-f(18)-f(19)+bfi(3))*dti
        Qi=Qi+jm                          ! total interface  momentum
        um=um+jm*ri                       ! total fluid velocity
        umi=umi+jm*ri                     ! total interface velocity
        ni=ni+1                           ! number of interface points
        tfi=tfi+bfi                       ! total interface force
c        if(mtype==1) then                       ! special interface collision matrix
c         svi=(svr*rr(i)+svb*rb(i))/ri           ! viscosity related interface eigen value
c         ci2=(cr2*rr(i)+cb2*rb(i))/ri           ! interface sound speed
c         vi=(1.D0/svi-0.5D0)*ci2                ! interface viscosity
c         permi=permi+ri*vi*u(idir)/bfi(idir)    ! calculate permeability
c        else                                    ! majority rule
c         if(rr(i)>=rb(i)) then                  ! red fluid collision matrix
c          permi=permi+ri*vr*u(idir)/bfi(idir)   ! calculate permeability
c         else                                   ! blue fluid collision matrix
c          permi=permi+ri*vb*u(idir)/bfi(idir)   ! calculate permeability
c         endif
c        endif
       endif
      enddo

c      if(nr<>0.D0)then
c       permr=umr(idir)*vr/(bf(idir)*nr)
c      endif
c      if(nb<>0.D0)then
c       permb=umb(idir)*vb/(bf(idir)*nb)
c      endif
c      if(ni<>0.D0)then
c       permi=permi/ni
c      endif

c     Qi=Qi/t0

      Qr=Qr/t0
      Qb=Qb/t0
      um=um/t0

c      um=(umr+umb+umi)/nl                        ! calculate mean flow velocity
c      permn=permi+permr+permb                    ! calculate permeability
c      Re=sqrt(dot_product(um,um))*lsize/vr       ! calculate Reynolds number
c      Mach=sqrt(dot_product(um,um))/sqrt(cb2)    ! calculate Mach number

      permr=Qr(idir)*vir/bfr(idir)  ! red fluid permeability  (lattice units)
      permb=Qb(idir)*vib/bfb(idir)  ! blue fluid permeability (lattice units)
c      permn=permr+permb

c      open(1,file='red_perm',position='append')
c      write(1,*)permr
c      close(1)
c      open(1,file='blue_perm',position='append')
c      write(1,*)permb
c      close(1)

c      Re=sqrt(dot_product(um,um))*lsize/vr
      Re=lsize*bmt(3)/(tmb*vir) ! Reynolds number

      if(abs(permro-permr)<eps.and.abs(permbo-permb)<eps) then ! convergence test
c       istop=1                                                 ! the program can be stoped
      endif
      permro = permr                                           ! assign new permeability value
      permbo = permb                                           ! assign new permeability value

c      if(Qr(1)<0.D0.or.Qb(1)<0.D0)then
c       istop=1 
c      endif 

      do k=1,ncz
       do j=1,ncy
        do i=1,ncx
         l=mijks(i,j,k) ! solid point number
         if(l.ne.0.d0)then
c          write(1,*)rdat(1:3,l) ! save coordinates
c          write(2,*)rdat(1:3,l)-icors(1:3,l) ! save displacements
c          write(3,*)vdat(1:3,l) ! save velocities
c          write(4,*)adat(1:3,l)/rsi ! save forces
           cstot=cstot+rdat(1:3,l)     ! mean solid coordinate
           vstot=vstot+vdat(1:3,l)     ! solid nodes total velocity
           fstot=fstot+adat(1:3,l)/rsi ! solid nodes total force
         endif
        enddo
       enddo
      enddo
      cstot=cstot/ns

c      open(1,file='red_flux',position='append')
c      write(1,*)umr/nr
c      close(1)
c      open(1,file='blue_flux',position='append')
c      write(1,*)umb/nb
c      close(1)
c      open(1,file='blue_bmt',position='append')
c      write(1,*)bmt(3),rmt(3)
c      close(1)
c      open(1,file='blue_bmt',position='append')
c      write(1,*)bmt(3),brt,bmt1(3)
c      close(1)

      write(17,*)'Reynolds number = ',Re
c     write(17,*)'Mach number = ',Mach
      write(17,*)'solid nodes total velocity vstot = ',vstot
      write(17,*)'solid nodes total force fstot = ',fstot
      write(17,*)'mean solid coordinate = cstot',cstot
      write(17,*)'total mass = ',tm
      write(17,*)'mean flow velocity(seepage) = ',um

      write(17,*)'total red mass = ',tmr
      write(17,*)'red mass flux/t0',Qr
      write(17,*)'red total force',dti*tfr*2.D0
      write(17,*)'total red velocity = ',umr
      write(17,*)'red number = ',nr
      write(17,*)'mean red velocity = ',umr/nr
      write(17,*)'red permeability ',permr

      write(17,*)'total blue mass = ',tmb 
      write(17,*)'blue mass flux/t0',Qb
      write(17,*)'blue total force',dti*tfb*2.D0
      write(17,*)'total blue velocity = ',umb
      write(17,*)'blue number = ',nb
      write(17,*)'mean blue velocity = ',umb/nb
      write(17,*)'blue permeability ',permb

c     write(17,*)'interface mass flux/t0',Qi
c     write(17,*)'interface total force',tfi
c     write(17,*)'Permeabilty total = ',perm
c     write(17,*)'interface velocity = ',umi
c     write(17,*)'interface number = ',ni
c     write(17,*)'interface permeability ',permi
      write(17,*)'istop = ',istop
      write(17,*)'eps for convergence test = ',eps
      if(isneg==1)then
        write(17,*)'ATTENTION!!!, there are negative populations'
      endif
      write(17,*)'--------------------'
      close(17)

      open(1,file='output.m',position='append')
      write(1,1984)it1*itw,permr,permb,
     &     0.03125D0*Qr(idir)*vir/sig,0.03125D0*Qb(idir)*vib/sig,
     &     0.03125D0*umr(idir)*vir*rr0/(nr*sig),
     &     0.03125D0*umb(idir)*vib*rb0/(nb*sig),
     &     Cpr-Cpb,Cpr,Cpb,
     &     nr/nl,nb/nl
      close(1)
1984  format(1X,I9,11(1X,E15.8),1X,';')


c      open(1,file='output.m',position='append')
c      write(1,*)it1*itw,permr,permb,
c     &          0.03125D0*Qr(idir)*vr/sig,0.03125D0*Qb(idir)*vb/sig,
c     &          Cpr-Cpb,Cpr,Cpb,
c     &          nr/nl,nb/nl,';'
c      close(1)

c      open(1,file='vel',position='append')
c      write(1,*)um
c      close(1)
      return
      end
c___________________________________________________
c    Majority rule LBM 
c     
c___________________________________________________
      subroutine majorityrule(ipcx,ipcy,ipcz,ind,c1d6,
     &  c1d12,c5d399,c19d399,
     &  c11d2394,c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72,
     &  c1d24,tr1,tr2,tr3,tb1,tb2,tb3,itm,itw,nl,fr,fb,ee,bfr,
     &  bfb,ncx,ncy,ncz,mijk,sig,wet,Sr,Sb,cb2,cr2,icor,
     &  svr,svb,B,nps,ips,npb2,ipb2,npb4,ipb4,iv,niv,idir,t0,
     &  lsize,rr0,rb0,eps,its,itms,ns,rdat,vdat,dt,adat,icors,
     &  nbo,bn,bon,bx,vb,alf1,bet1,alf2,bet2,
     &  nna,vn,ang,vx,vv,anf,rsi,mijks,
     &  abond,sbond,nthread2,lib,lia,Em,nu,inds,iipore,npores)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 fr(19,nl),fb(19,nl)
      real*8 bfr(3),bfb(3)
      real*8 Sr(19),Sb(19)
      integer*4 ncx,ncy,ncz
      integer*4 nl     ! real number of the liquid points
      integer*4 nps    ! dimension of the ips
      integer*4 npb2    ! dimension of the ipb2
      integer*4 npb4    ! dimension of the ipb4
c      integer*4 npm    ! dimension of the ipm

      integer*4 mijk(ncx,ncy,ncz)
      integer*4 icor(3,nl)
      integer*4 ips(3,nps)
      integer*4 ipb2(4,npb2)
      integer*4 ipb4(6,npb4)
c      integer*4 ipm(4,npm)
      integer   iv(3,19)          ! discrete velocities
      integer   niv(19)           ! numbers of the opposite velocities
      real*8 vir        ! red fluid viscosity
      real*8 vib        ! blue fluid viscosity
 
      real*8 Fpr(19),Fpb(19)
      real*8 pcfr(19,nl),pcfb(19,nl)  ! can be created here   
      real*8 rr(nl),rb(nl),cf(nl)

      character*8  date               ! current date
      character*10 time               ! current time
      integer*4 ic(3)
      real*8  Cg(3)                    ! color gradient
      real*8  Fs(3)
      real*8  f(19)    
      real*8  ri
      real*8  ci2,svi,bfi(3),Si(19),Fpi(19)
      real*8  pcf(19)
      real*8  cosf(18)
c     real*8  iv2(3,18),cn(18)
      real*8  cn ! norm inverse

      real*8  permro,permbo           ! old permeability values for convergance test
      integer istop                   ! check for quit
      real*8 ti1,ti2,ti3
      real*8 c1d6,c1d12,c5d399,c19d399
      real*8 c11d2394,c1d63,c1d18,c1d36
      real*8 c4d1197,c1d252,c1d72,c1d24
      real*8 tr1,tr2,tr3,tb1,tb2,tb3
      real*8 rk(19)
      integer ind(ncx,ncy,ncz)    ! unit cell: 1-pore, 0-solid
      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2)
      integer itms

      integer*4 ns          ! number of solid points
      real*8    rdat(3,ns)  ! elastic solid points coordinates
      real*8    vdat(3,ns)  ! elastic solid points velocity
      real*8    dt,dti,dt2  ! time step, time step inverse, time step square
      real*8    adat(3,ns)  ! elastic solid points acceleration
      real*8    afdat(3,ns) ! fluid boundary force
      integer*4 icors(3,ns) ! coordinates of the solid points
      integer*8 nbo         ! bonds counter
      real*8    bn(3,9)     ! normalized vectors
      integer*4 bon(3,nbo)  ! bonds
      real*8    bx(3,9)     ! xn/|rn|
      real*8    vb(3,9)     ! bond vectors (real numbers)
      real*8    alf1,bet1              ! elastic constants^M
      real*8    alf2,bet2

      integer*8 nna ! angles counter
      real*8    vn(3,19) ! discrete velocities normalized
      integer*4 ang(6,nna) !angles array
      real*8    vx(3,19) ! xn/|rn|
      real*8    vv(3,19) ! discrete velocities (real numbers)
      real*8    anf(9,48) ! angle plane normal, angular force vectors j k; for angular springs
      real*8    rsi ! inverse of solid body density
      real*8    ubc ! solid point velocity projection
      real*8    ti(19)
      integer*4 mijks(ncx,ncy,ncz)
      real*8 tr(19),tb(19),c2pidlx,rtime
      real*8 F1(3),F1V(3),F1D(3),F2(3),F3(3)
      real*8 rsdti2,rs
      real*8  bfim(3),Fpim(19)
      real*8  fq(19)

      real*8    abond(nna),sbond(nbo)
      integer   nthread2            ! = nthread*2
      integer*8 lib(nthread2+1),lia(nthread2+1)
      real*8  vsf(3),floc(3)
      real*8 Em ! Young modulus LSM
      real*8 nu ! Poisson's ratio LSM
      integer inds(ncx,ncy,ncz)
      real*8 pres,ppp ! pressure, pressure parameter
      integer iipore ! pore filled with fluid
      integer npores ! number of distinct pores  


      ppp=0.99D0

      bfim = (/(0.D0,i=1,3)/)
      Fpim = (/(0.D0,i=1,19)/)       

      dti=1.D0/dt
      rs=1.D0/rsi
      rsdti2=rsi*dti*dti
      dt2=dt*dt
      vir=dti*(1.D0/svr-0.5D0)/3.D0  ! red fluid viscosity
      vib=dti*(1.D0/svb-0.5D0)/3.D0  ! blue fluid viscosity
      fq = rr0*(/0.D0,(cr2*c1d6*dt2,i=1,6),(cr2*c1d12*dt2,i=1,12)/)

      permro=0.D0               ! initialize permeability
      permbo=0.D0               ! initialize permeability
      istop=0                   ! initialize istop
      is = 0                    ! check for save index

      c2pidlx  = 6.283185307179586D0/500.D0
      tr=(/tr1,(tr2,i=1,6),(tr3,i=1,12)/)
      tb=(/tb1,(tb2,i=1,6),(tb3,i=1,12)/)

      rk=(/1.D0,(c1d6,i=1,6),(c1d12,i=1,12)/) ! vector calculated once
      Fpr=rk*matmul(transpose(vv),bfr)*dt2   ! red fluid body force projections
      Fpb=rk*matmul(transpose(vv),bfb)*dt2   ! blue fluid body force projections
c      iv2=iv(1:3,2:19) ! discrete velocities for anti-diffusion sheme
c      do i=1,18        ! calculate discrete velocities norms
c       cn(i)=sqrt(dot_product(iv2(1:3,i),iv2(1:3,i)))
c      enddo
       cn = 1.D0/sqrt(2.D0) ! velocity vector norm inverse
!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nl,rr,fr,rb,fb,cf)
        do i=1,nl                          ! calculate color and density fields and interface
         rr(i)=fr(1,i)+fr(2,i)+fr(3,i)+fr(4,i)+fr(5,i)+fr(6,i)+fr(7,i)
     &        +fr(8,i)+fr(9,i)+fr(10,i)+fr(11,i)+fr(12,i)+fr(13,i)
     &        +fr(14,i)+fr(15,i)+fr(16,i)+fr(17,i)+fr(18,i)+fr(19,i)
         rb(i)=fb(1,i)+fb(2,i)+fb(3,i)+fb(4,i)+fb(5,i)+fb(6,i)+fb(7,i)
     &        +fb(8,i)+fb(9,i)+fb(10,i)+fb(11,i)+fb(12,i)+fb(13,i)
     &        +fb(14,i)+fb(15,i)+fb(16,i)+fb(17,i)+fb(18,i)+fb(19,i)
         cf(i)=(rr(i)-rb(i))/(rr(i)+rb(i)) ! color field
        enddo
!$OMP END PARALLEL DO

! INITIALIZATION PROCESS
      open(15,file = 'LOG')
      write(15,*)'initialization started'
      close(15)

      do it1=1,2          ! main iteration circle
       do it2=1,1      ! intermediate iteration circle
!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i,j,ll,bfr,Fpr,Sr,bfb,Fpb,Sb,ipcx,ipcy,ipcz)
!$OMP& PRIVATE(ic,ncx,ncy,ncz,Cg,Fs,f,ri,ci2,cb2)
!$OMP& PRIVATE(svi,bfi,Si,Fpi,pcf,cosf,cn)
!$OMP& PRIVATE(c1d6,c1d12,c5d399,c19d399,c11d2394)
!$OMP& PRIVATE(c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72)
!$OMP& PRIVATE(c1d24,tr1,tr2,tr3,tb1,tb2,tb3,ti1,ti2,ti3)
!$OMP& FIRSTPRIVATE(c1d6,c1d12,c5d399,c19d399,c11d2394)
!$OMP& FIRSTPRIVATE(c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72)
!$OMP& FIRSTPRIVATE(c1d24,tr1,tr2,tr3,tb1,tb2,tb3)
!$OMP& FIRSTPRIVATE(bfr,Fpr,Sr,bfb,Fpb,Sb,ipcx,ipcy,ipcz)
!$OMP& FIRSTPRIVATE(ncx,ncy,ncz,cb2,cn)
!$OMP& FIRSTPRIVATE(dt,dti,dt2)
!$OMP& SHARED(nl,rb,fr,pcfr,rr,pcfb,fb,icor,mijk,cf)
!$OMP& SHARED(ee,sig,wet,cr2,svr,svb,B,ind)
        do i=1,nl                     ! collision step (red fluid is dominant)
         if(rb(i)<=ee) then           ! red or blue bulk fluid
          call collision(tr1,tr2,tr3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         fr(1:19,i),pcfr(1:19,i),rr(i),bfr,Fpr,Sr,dt,dti,dt2)
          fb(1,i)=tb1*rb(i)
          pcfb(2:19,i)=(/(tb2*rb(i),j=1,6),(tb3*rb(i),j=1,12)/)
         elseif(rr(i)<=ee) then
          call collision(tb1,tb2,tb3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         fb(1:19,i),pcfb(1:19,i),rb(i),bfb,Fpb,Sb,dt,dti,dt2)
          fr(1,i)=tr1*rr(i)
          pcfr(2:19,i)=(/(tr2*rr(i),j=1,6),(tr3*rr(i),j=1,12)/)
         else
          ic=icor(1:3,i)                                       ! interface point coordinates
          call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &         ,Cg,Fs,sig,wet) ! surface tension force
          f=fr(1:19,i)+fb(1:19,i)                ! calculate common particles distribution
          ri=rr(i)+rb(i)                         ! fluid density at interface
          ci2=(cr2*rr(i)+cb2*rb(i))/ri           ! interface sound speed
          ti1=1.D0-2.D0*ci2*dt2
          ti2=ci2*c1d6*dt2
          ti3=ci2*c1d12*dt2 ! interface lattice weights

           if(rr(i)>=rb(i)) then                   ! red fluid collision matrix
            bfi=bfr+Fs                             ! interface body force
            Fpi(1)=0.D0                            ! body force projections
            Fpi(2)= c1d6*bfi(1)*dt2
            Fpi(3)=-Fpi(2)
            Fpi(4)= c1d6*bfi(2)*dt2
            Fpi(5)=-Fpi(4)
            Fpi(6)= c1d6*bfi(3)*dt2
            Fpi(7)=-Fpi(6)
            Fpi(8)= c1d12*(bfi(1)+bfi(2))*dt2
            Fpi(9)= c1d12*(-bfi(1)+bfi(2))*dt2
            Fpi(10)= -Fpi(9)
            Fpi(11)= -Fpi(8)
            Fpi(12)= c1d12*(bfi(1)+bfi(3))*dt2
            Fpi(13)= c1d12*(-bfi(1)+bfi(3))*dt2
            Fpi(14)= -Fpi(13)
            Fpi(15)= -Fpi(12)
            Fpi(16)= c1d12*(bfi(2)+bfi(3))*dt2
            Fpi(17)= c1d12*(-bfi(2)+bfi(3))*dt2
            Fpi(18)= -Fpi(17)
            Fpi(19)= -Fpi(16)
            call collision(ti1,ti2,ti3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         f,pcf,ri,bfi,Fpi,Sr,dt,dti,dt2)
           else                                    ! blue fluid collision matrix
            bfi=bfb+Fs                             ! interface body force
            Fpi(1)=0.D0                            ! body force projections
            Fpi(2)= c1d6*bfi(1)*dt2
            Fpi(3)=-Fpi(2)
            Fpi(4)= c1d6*bfi(2)*dt2
            Fpi(5)=-Fpi(4)
            Fpi(6)= c1d6*bfi(3)*dt2
            Fpi(7)=-Fpi(6)
            Fpi(8)= c1d12*(bfi(1)+bfi(2))*dt2
            Fpi(9)= c1d12*(-bfi(1)+bfi(2))*dt2
            Fpi(10)= -Fpi(9)
            Fpi(11)= -Fpi(8)
            Fpi(12)= c1d12*(bfi(1)+bfi(3))*dt2
            Fpi(13)= c1d12*(-bfi(1)+bfi(3))*dt2
            Fpi(14)= -Fpi(13)
            Fpi(15)= -Fpi(12)
            Fpi(16)= c1d12*(bfi(2)+bfi(3))*dt2
            Fpi(17)= c1d12*(-bfi(2)+bfi(3))*dt2
            Fpi(18)= -Fpi(17)
            Fpi(19)= -Fpi(16)
            call collision(ti1,ti2,ti3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         f,pcf,ri,bfi,Fpi,Sb,dt,dti,dt2)
           endif

          cosf(1)= Cg(1)
          cosf(2)=-cosf(1)
          cosf(3)= Cg(2)
          cosf(4)=-cosf(3)
          cosf(5)= Cg(3)
          cosf(6)=-cosf(5)
          cosf(7)= (Cg(1)+Cg(2))*cn
          cosf(8)= (-Cg(1)+Cg(2))*cn
          cosf(9)= -cosf(8)
          cosf(10)= -cosf(7)
          cosf(11)= (Cg(1)+Cg(3))*cn
          cosf(12)= (-Cg(1)+Cg(3))*cn
          cosf(13)= -cosf(12)
          cosf(14)= -cosf(11)
          cosf(15)= (Cg(2)+Cg(3))*cn
          cosf(16)= (-Cg(2)+Cg(3))*cn
          cosf(17)= -cosf(16)
          cosf(18)= -cosf(15)

          fr(1,i)=f(1)*rr(i)/ri                ! zero velocity segregation
          fb(1,i)=f(1)*rb(i)/ri                ! zero velocity segregation

          do ll=2,7
           pcfr(ll,i)=(pcf(ll)+B*ti2*cosf(ll-1)*rb(i))*rr(i)/ri ! anti-diffusion
           pcfb(ll,i)=(pcf(ll)-B*ti2*cosf(ll-1)*rr(i))*rb(i)/ri ! anti-diffusion
          enddo

          do ll=8,19
           pcfr(ll,i)=(pcf(ll)+B*ti3*cosf(ll-1)*rb(i))*rr(i)/ri ! anti-diffusion
           pcfb(ll,i)=(pcf(ll)-B*ti3*cosf(ll-1)*rr(i))*rb(i)/ri ! anti-diffusion
          enddo
         endif
        enddo
!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nps,ips,fr,pcfr,fb,pcfb)
        do i=1,nps                                ! simple propagation
         fr(ips(3,i),ips(2,i))=pcfr(ips(3,i),ips(1,i))
         fb(ips(3,i),ips(2,i))=pcfb(ips(3,i),ips(1,i))
        enddo
!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(npb2,ipb2,fr,pcfr,fb,pcfb,niv)
        do i=1,npb2 ! bounce-back 
         fr(ipb2(2,i),ipb2(1,i))=pcfr(niv(ipb2(2,i)),ipb2(1,i))
         fb(ipb2(2,i),ipb2(1,i))=pcfb(niv(ipb2(2,i)),ipb2(1,i))
        enddo
!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(npb4,ipb4,fr,pcfr,fb,pcfb,niv)
        do i=1,npb4 ! bounce-back
         fr(ipb4(2,i),ipb4(1,i))=pcfr(niv(ipb4(2,i)),ipb4(1,i))
         fb(ipb4(2,i),ipb4(1,i))=pcfb(niv(ipb4(2,i)),ipb4(1,i))
        enddo
!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nl,rr,fr,rb,fb,cf)
        do i=1,nl                          ! calculate color and density fields and interface
         rr(i)=fr(1,i)+fr(2,i)+fr(3,i)+fr(4,i)+fr(5,i)+fr(6,i)+fr(7,i)
     &        +fr(8,i)+fr(9,i)+fr(10,i)+fr(11,i)+fr(12,i)+fr(13,i)
     &        +fr(14,i)+fr(15,i)+fr(16,i)+fr(17,i)+fr(18,i)+fr(19,i)
         rb(i)=fb(1,i)+fb(2,i)+fb(3,i)+fb(4,i)+fb(5,i)+fb(6,i)+fb(7,i)
     &        +fb(8,i)+fb(9,i)+fb(10,i)+fb(11,i)+fb(12,i)+fb(13,i)
     &        +fb(14,i)+fb(15,i)+fb(16,i)+fb(17,i)+fb(18,i)+fb(19,i)
         cf(i)=(rr(i)-rb(i))/(rr(i)+rb(i)) ! color field
        enddo
!$OMP END PARALLEL DO
       enddo
      enddo
! INITIALIZATION PROCESS END

c        call save_results(ipcx,ipcy,ipcz,ind,nl,fr,fb,vv,mijk,ncx,ncy
c     &       ,ncz,icor,sig,cr2,cb2,wet,it1,bfr,bfb,itw,rr,rb,cf
c     &       ,rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti,afdat)         ! save results

      open(15,file = 'LOG')
      write(15,*)'initialization finished'
      close(15)

      do it1=itms,itm          ! main iteration circle
       is=is+1
       do it2=1,itw         ! intermediate iteration circle

c        pcfr=0              ! set post-collision matrix to zero
c        pcfb=0              ! set post-collision matrix to zero

! Attention !!! fr(1,i) and fb(1,i) will be changed => passed fr and fr not correct
!!! discrete zero velocity is not propagated

       rtime = it2+(it1-1)*itw-1 ! time for SIN
       if(rtime.gt.500)then
        rtime = 0.D0
       endif
       rtime = c2pidlx*rtime

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i,j,ll,bfr,Fpr,Sr,bfb,Fpb,Sb,ipcx,ipcy,ipcz)
!$OMP& PRIVATE(ic,ncx,ncy,ncz,Cg,Fs,f,ri,ci2,cb2)
!$OMP& PRIVATE(svi,bfi,Si,Fpi,pcf,cosf,cn,bfim,Fpim)
!$OMP& PRIVATE(c1d6,c1d12,c5d399,c19d399,c11d2394)
!$OMP& PRIVATE(c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72)
!$OMP& PRIVATE(c1d24,tr1,tr2,tr3,tb1,tb2,tb3,ti1,ti2,ti3)
!$OMP& FIRSTPRIVATE(c1d6,c1d12,c5d399,c19d399,c11d2394)
!$OMP& FIRSTPRIVATE(c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72)
!$OMP& FIRSTPRIVATE(c1d24,tr1,tr2,tr3,tb1,tb2,tb3)
!$OMP& FIRSTPRIVATE(bfr,Fpr,Sr,bfb,Fpb,Sb,ipcx,ipcy,ipcz)
!$OMP& FIRSTPRIVATE(ncx,ncy,ncz,cb2,cn)
!$OMP& FIRSTPRIVATE(dt,dti,dt2)
!$OMP& SHARED(nl,rb,fr,pcfr,rr,pcfb,fb,icor,mijk,cf)
!$OMP& SHARED(ee,sig,wet,cr2,svr,svb,B,ind)
        do i=1,nl                     ! collision step (red fluid is dominant)
cc         if(icor(1,i).eq.150.and.rtime.gt.0.D0) then
cc           pcfr(1:19,i)=tr*(rr(i)+0.1D0*SIN(rtime))
cc           fr(1,i) = tr1*rr(i)

c          pcfr(1:19,i)=tr*(rr(i)+0.1D0*SIN(rtime)*rr(i)/(rr(i)+rb(i)))
c          pcfb(1:19,i)=tb*(rb(i)+0.1D0*SIN(rtime)*rb(i)/(rr(i)+rb(i)))
c
c          fr(1,i) = tr1*rr(i)
c          fb(1,i) = tb1*rb(i)
cc         else
c
c          ic=icor(1:3,i)
c          call calcIMP(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz
c     &                  ,cf,nl,ic,Cg,bfim,-0.25D0,wet,rr,rb)
c
            bfim=(/0.D0,0.D0,0.D0/)

            Fpim(1)=0.D0                            ! body force projections
            Fpim(2)= c1d6*bfim(1)*dt2
            Fpim(3)=-Fpim(2)
            Fpim(4)= c1d6*bfim(2)*dt2
            Fpim(5)=-Fpim(4)
            Fpim(6)= c1d6*bfim(3)*dt2
            Fpim(7)=-Fpim(6)
            Fpim(8)= c1d12*(bfim(1)+bfim(2))*dt2
            Fpim(9)= c1d12*(-bfim(1)+bfim(2))*dt2
            Fpim(10)= -Fpim(9)
            Fpim(11)= -Fpim(8)
            Fpim(12)= c1d12*(bfim(1)+bfim(3))*dt2
            Fpim(13)= c1d12*(-bfim(1)+bfim(3))*dt2
            Fpim(14)= -Fpim(13)
            Fpim(15)= -Fpim(12)
            Fpim(16)= c1d12*(bfim(2)+bfim(3))*dt2
            Fpim(17)= c1d12*(-bfim(2)+bfim(3))*dt2
            Fpim(18)= -Fpim(17)
            Fpim(19)= -Fpim(16)

         if(rb(i)<=ee) then           ! red or blue bulk fluid
          call collision(tr1,tr2,tr3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         fr(1:19,i),pcfr(1:19,i),rr(i),bfr+bfim,Fpr+Fpim,Sr,
     &         dt,dti,dt2)
          fb(1,i)=tb1*rb(i)
          pcfb(2:19,i)=(/(tb2*rb(i),j=1,6),(tb3*rb(i),j=1,12)/)
c         pcfb(1:19,i)=(/tb1*rb(i),(tb2*rb(i),j=1,6),(tb3*rb(i),j=1,12)/)
c          call fequil(rk,tb,rb(i),bfb,fb(1:19,i),pcfb(1:19,i))
         elseif(rr(i)<=ee) then
          call collision(tb1,tb2,tb3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         fb(1:19,i),pcfb(1:19,i),rb(i),bfb+bfim,Fpb+Fpim,Sb,
     &         dt,dti,dt2)
          fr(1,i)=tr1*rr(i)
          pcfr(2:19,i)=(/(tr2*rr(i),j=1,6),(tr3*rr(i),j=1,12)/)
c         pcfr(1:19,i)=(/tr1*rr(i),(tr2*rr(i),j=1,6),(tr3*rr(i),j=1,12)/)
c          call fequil(rk,tr,rr(i),bfr,fr(1:19,i),pcfr(1:19,i))
         else
          ic=icor(1:3,i)                                       ! interface point coordinates
          call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &         ,Cg,Fs,sig,wet) ! surface tension force
          f=fr(1:19,i)+fb(1:19,i)                ! calculate common particles distribution
          ri=rr(i)+rb(i)                         ! fluid density at interface
          ci2=(cr2*rr(i)+cb2*rb(i))/ri           ! interface sound speed
          ti1=1.D0-2.D0*ci2*dt2
          ti2=ci2*c1d6*dt2
          ti3=ci2*c1d12*dt2 ! interface lattice weights

           if(rr(i)>=rb(i)) then                   ! red fluid collision matrix
            bfi=bfr+Fs                             ! interface body force
            Fpi(1)=0.D0                            ! body force projections
            Fpi(2)= c1d6*bfi(1)*dt2
            Fpi(3)=-Fpi(2)
            Fpi(4)= c1d6*bfi(2)*dt2
            Fpi(5)=-Fpi(4)
            Fpi(6)= c1d6*bfi(3)*dt2
            Fpi(7)=-Fpi(6)
            Fpi(8)= c1d12*(bfi(1)+bfi(2))*dt2
            Fpi(9)= c1d12*(-bfi(1)+bfi(2))*dt2
            Fpi(10)= -Fpi(9)
            Fpi(11)= -Fpi(8) 
            Fpi(12)= c1d12*(bfi(1)+bfi(3))*dt2
            Fpi(13)= c1d12*(-bfi(1)+bfi(3))*dt2
            Fpi(14)= -Fpi(13)
            Fpi(15)= -Fpi(12)
            Fpi(16)= c1d12*(bfi(2)+bfi(3))*dt2
            Fpi(17)= c1d12*(-bfi(2)+bfi(3))*dt2
            Fpi(18)= -Fpi(17)
            Fpi(19)= -Fpi(16)
            call collision(ti1,ti2,ti3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         f,pcf,ri,bfi+bfim,Fpi+Fpim,Sr,dt,dti,dt2)
           else                                    ! blue fluid collision matrix
            bfi=bfb+Fs                             ! interface body force
            Fpi(1)=0.D0                            ! body force projections
            Fpi(2)= c1d6*bfi(1)*dt2
            Fpi(3)=-Fpi(2)
            Fpi(4)= c1d6*bfi(2)*dt2
            Fpi(5)=-Fpi(4)
            Fpi(6)= c1d6*bfi(3)*dt2
            Fpi(7)=-Fpi(6)
            Fpi(8)= c1d12*(bfi(1)+bfi(2))*dt2
            Fpi(9)= c1d12*(-bfi(1)+bfi(2))*dt2
            Fpi(10)= -Fpi(9)
            Fpi(11)= -Fpi(8)
            Fpi(12)= c1d12*(bfi(1)+bfi(3))*dt2
            Fpi(13)= c1d12*(-bfi(1)+bfi(3))*dt2
            Fpi(14)= -Fpi(13)
            Fpi(15)= -Fpi(12)
            Fpi(16)= c1d12*(bfi(2)+bfi(3))*dt2
            Fpi(17)= c1d12*(-bfi(2)+bfi(3))*dt2
            Fpi(18)= -Fpi(17)
            Fpi(19)= -Fpi(16)
            call collision(ti1,ti2,ti3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         f,pcf,ri,bfi+bfim,Fpi+Fpim,Sb,dt,dti,dt2)
           endif

c         cosf=matmul(Cg,iv2)/cn                   ! cos for anti-diffusion
          cosf(1)= Cg(1)
          cosf(2)=-cosf(1)
          cosf(3)= Cg(2)
          cosf(4)=-cosf(3)
          cosf(5)= Cg(3)
          cosf(6)=-cosf(5)
          cosf(7)= (Cg(1)+Cg(2))*cn
          cosf(8)= (-Cg(1)+Cg(2))*cn
          cosf(9)= -cosf(8)
          cosf(10)= -cosf(7)
          cosf(11)= (Cg(1)+Cg(3))*cn
          cosf(12)= (-Cg(1)+Cg(3))*cn
          cosf(13)= -cosf(12)
          cosf(14)= -cosf(11)
          cosf(15)= (Cg(2)+Cg(3))*cn
          cosf(16)= (-Cg(2)+Cg(3))*cn
          cosf(17)= -cosf(16)
          cosf(18)= -cosf(15)
    
c          pcfr(1,i)=pcf(1)*rr(i)/ri           ! zero velocity segregation
c          pcfb(1,i)=pcf(1)*rb(i)/ri           ! zero velocity segregation
          fr(1,i)=f(1)*rr(i)/ri                ! zero velocity segregation
          fb(1,i)=f(1)*rb(i)/ri                ! zero velocity segregation

          do ll=2,7
           pcfr(ll,i)=(pcf(ll)+B*ti2*cosf(ll-1)*rb(i))*rr(i)/ri ! anti-diffusion
           pcfb(ll,i)=(pcf(ll)-B*ti2*cosf(ll-1)*rr(i))*rb(i)/ri ! anti-diffusion
          enddo
          do ll=8,19
           pcfr(ll,i)=(pcf(ll)+B*ti3*cosf(ll-1)*rb(i))*rr(i)/ri ! anti-diffusion
           pcfb(ll,i)=(pcf(ll)-B*ti3*cosf(ll-1)*rr(i))*rb(i)/ri ! anti-diffusion
          enddo
         endif
c         endif
        enddo
!$OMP END PARALLEL DO

c        fr=0   ! set to zero red fluid matrix
c        fb=0   ! set to zero blue fluid matrix

c!$OMP  PARALLEL DO PRIVATE(i)
c!$OMP& SHARED(nl,fr,pcfr,fb,pcfb)
c        do i=1,nl            ! it works correct - full substitution fr by pcfr and fb by pcfb
c         fr(1,i)=pcfr(1,i)   ! zero velocity component redifinition
c         fb(1,i)=pcfb(1,i)
c        enddo
c!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nps,ips,fr,pcfr,fb,pcfb)
        do i=1,nps                                ! simple propagation
         fr(ips(3,i),ips(2,i))=pcfr(ips(3,i),ips(1,i))
         fb(ips(3,i),ips(2,i))=pcfb(ips(3,i),ips(1,i))
        enddo
!$OMP END PARALLEL DO

c!$OMP  PARALLEL DO PRIVATE(i)
c!$OMP& SHARED(npb,ipb,niv,fr,pcfr,fb,pcfb)
c        do i=1,npb                                ! bounce back boundary condition
c         fr(ipb(2,i),ipb(1,i))=pcfr(niv(ipb(2,i)),ipb(1,i))
c         fb(ipb(2,i),ipb(1,i))=pcfb(niv(ipb(2,i)),ipb(1,i))
c        enddo
c!$OMP END PARALLEL DO

        afdat=0.D0 ! initialize afdat

        do i=1,npb2 ! LSM-LBM coupling - boundary
c         vsf=(vdat(1:3,ipb2(3,i))+vdat(1:3,ipb2(4,i)))*0.5D0
c
c         ubc=(vsf(1)*vv(1,ipb2(2,i))+vsf(2)*vv(2,ipb2(2,i))
c     &       +vsf(3)*vv(3,ipb2(2,i)))*dt

         floc = -2.D0*((pcfr(niv(ipb2(2,i)),ipb2(1,i))
     &   +pcfb(niv(ipb2(2,i)),ipb2(1,i)))
c     &   +rk(ipb2(2,i))*ubc*(rr(ipb2(1,i))+rb(ipb2(1,i)))
     &   -ppp*fq(ipb2(2,i)))*vv(1:3,ipb2(2,i))*rsdti2

         afdat(1:3,ipb2(3,i))=afdat(1:3,ipb2(3,i))+floc*0.5D0
         afdat(1:3,ipb2(4,i))=afdat(1:3,ipb2(4,i))+floc*0.5D0
        enddo

        do i=1,npb4 ! LSM-LBM coupling - boundary
c         vsf=(vdat(1:3,ipb4(3,i))+vdat(1:3,ipb4(4,i))
c     &       +vdat(1:3,ipb4(5,i))+vdat(1:3,ipb4(6,i)))*0.25D0
c
c         ubc=(vsf(1)*vv(1,ipb4(2,i))+vsf(2)*vv(2,ipb4(2,i))
c     &       +vsf(3)*vv(3,ipb4(2,i)))*dt

         floc = -2.D0*((pcfr(niv(ipb4(2,i)),ipb4(1,i))
     &   +pcfb(niv(ipb4(2,i)),ipb4(1,i)))
c     &   +rk(ipb4(2,i))*ubc*(rr(ipb4(1,i))+rb(ipb4(1,i)))
     &   -ppp*fq(ipb4(2,i)))*vv(1:3,ipb4(2,i))*rsdti2

         afdat(1:3,ipb4(3,i))=afdat(1:3,ipb4(3,i))+floc*0.25D0
         afdat(1:3,ipb4(4,i))=afdat(1:3,ipb4(4,i))+floc*0.25D0
         afdat(1:3,ipb4(5,i))=afdat(1:3,ipb4(5,i))+floc*0.25D0
         afdat(1:3,ipb4(6,i))=afdat(1:3,ipb4(6,i))+floc*0.25D0
        enddo

        call lsm_step(ns,rdat,vdat,dt,adat,icors,
     &                    nbo,bn,bon,bx,vb,
     &                    nna,vn,ang,vx,vv,anf,rsi,afdat,rtime,
     &                    abond,sbond,nthread2,
     &                    lib,lia)

        do i=1,npb2 ! LSM-LBM coupling - boundary
c         vsf=(vdat(1:3,ipb2(3,i))+vdat(1:3,ipb2(4,i)))*0.5D0
c
c         ubc=(vsf(1)*vv(1,ipb2(2,i))+vsf(2)*vv(2,ipb2(2,i))
c     &       +vsf(3)*vv(3,ipb2(2,i)))*dt

         fr(ipb2(2,i),ipb2(1,i))=pcfr(niv(ipb2(2,i)),ipb2(1,i))
c     &   +2.D0*rk(ipb2(2,i))*rr(ipb2(1,i))*ubc

         fb(ipb2(2,i),ipb2(1,i))=pcfb(niv(ipb2(2,i)),ipb2(1,i))
c     &   +2.D0*rk(ipb2(2,i))*rb(ipb2(1,i))*ubc
        enddo

        do i=1,npb4 ! LSM-LBM coupling - boundary
c         vsf=(vdat(1:3,ipb4(3,i))+vdat(1:3,ipb4(4,i))
c     &       +vdat(1:3,ipb4(5,i))+vdat(1:3,ipb4(6,i)))*0.25D0
c
c         ubc=(vsf(1)*vv(1,ipb4(2,i))+vsf(2)*vv(2,ipb4(2,i))
c     &       +vsf(3)*vv(3,ipb4(2,i)))*dt

         fr(ipb4(2,i),ipb4(1,i))=pcfr(niv(ipb4(2,i)),ipb4(1,i))
c     &   +2.D0*rk(ipb4(2,i))*rr(ipb4(1,i))*ubc

         fb(ipb4(2,i),ipb4(1,i))=pcfb(niv(ipb4(2,i)),ipb4(1,i))
c     &   +2.D0*rk(ipb4(2,i))*rb(ipb4(1,i))*ubc
        enddo

c!$OMP  PARALLEL DO PRIVATE(i)
c!$OMP& SHARED(npm,ipm,niv,fr,pcfr,fb,pcfb)
c        do i=1,npm                                ! multireflection boundary condition
c         fr(ipm(4,i),ipm(1,i))=pcfr(niv(ipm(4,i)),ipm(1,i)) ! bounce back
c         fb(ipm(4,i),ipm(1,i))=pcfb(niv(ipm(4,i)),ipm(1,i)) ! bounce back
c         q=ipmq(i)
c         q1=(1.D0-2.D0*q-2.D0*q**2)/((1.D0+q)**2)
c         q2=(q**2)/((1.D0+q)**2)
c         q3=1.D0/(4.D0*nu*((1.D0+q)**2))
c         f(ipm(1,i),ipm(4,i))=
c     &   pcf(ipm(1,i),niv(ipm(4,i)))+q1*pcf(ipm(2,i),niv(ipm(4,i)))
c     &   +q2*pcf(ipm(3,i),niv(ipm(4,i)))-q1*pcf(ipm(1,i),ipm(4,i))
c     &   -q2*pcf(ipm(2,i),ipm(4,i))
c     &   +q3*f2(ipm(4,i))
c        enddo
c!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nl,rr,fr,rb,fb,cf)
        do i=1,nl                          ! calculate color and density fields and interface
         rr(i)=fr(1,i)+fr(2,i)+fr(3,i)+fr(4,i)+fr(5,i)+fr(6,i)+fr(7,i)
     &        +fr(8,i)+fr(9,i)+fr(10,i)+fr(11,i)+fr(12,i)+fr(13,i)
     &        +fr(14,i)+fr(15,i)+fr(16,i)+fr(17,i)+fr(18,i)+fr(19,i)
         rb(i)=fb(1,i)+fb(2,i)+fb(3,i)+fb(4,i)+fb(5,i)+fb(6,i)+fb(7,i)
     &        +fb(8,i)+fb(9,i)+fb(10,i)+fb(11,i)+fb(12,i)+fb(13,i)
     &        +fb(14,i)+fb(15,i)+fb(16,i)+fb(17,i)+fb(18,i)+fb(19,i)
         cf(i)=(rr(i)-rb(i))/(rr(i)+rb(i)) ! color field
        enddo
!$OMP END PARALLEL DO

       enddo

c       CALL DATE_AND_TIME(date, time)
c       write(1313,*)'save start = ',time
       open(1,file='iteration')
       write(1,*)it1
       write(1,*)((fr(j,i),j=1,19),i=1,nl)
       write(1,*)((fb(j,i),j=1,19),i=1,nl)
       close(1)
       open(1,file='iteration2')
       write(1,*)it1
       write(1,*)((fr(j,i),j=1,19),i=1,nl)
       write(1,*)((fb(j,i),j=1,19),i=1,nl)
       close(1)
       call system('rm iteration')

       if(is==its) then
        is=0
        call save_results(ipcx,ipcy,ipcz,ind,nl,fr,fb,vv,mijk,ncx,ncy
     &       ,ncz,icor,sig,cr2,cb2,wet,it1,bfr,bfb,itw,rr,rb,cf
     &       ,rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti,afdat)         ! save results
       endif

c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'save end = ',time
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'parallel region end = ',time
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'check start = ',time

       call check_state(ipcx,ipcy,ipcz,ind,it1,fr,fb,nl,rr0,rb0,eps,
     &   ncx,ncy,ncz,istop,lsize,mijk,
     &   vir,vib,idir,t0,icor,sig,vv,cr2,cb2,
     &   wet,bfr,bfb,itw,rr,rb,cf,permro,permbo,
     &   rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti)   ! check program state

       call calc_stress(ns,rdat,icors,bn,vb,vn,vx,vv,anf,
     &                    ncx,ncy,ncz,mijks,ipcx,ipcy,ipcz,
     &                    ind,inds,alf1,bet1,alf2,bet2,Em,nu)

       pres=(1.D0-ppp)*rr0*cr2
       call calc_ab(ns,rdat,icors,bn,vb,vn,vx,vv,anf,
     &                    ncx,ncy,ncz,mijks,ipcx,ipcy,ipcz,
     &                    ind,inds,alf1,bet1,alf2,bet2,Em,nu,npb2,ipb2,
     &                    npb4,ipb4,iv,pres,iipore,npores)



c       if(istop==1) then                                              ! check for quit
c        return 
c       endif
c       CALL DATE_AND_TIME(date, time)
c       write(1313,*)'check end = ',time

      enddo

      return
      end
c---------------------------------------------------------------
c calculate alpha, beta coefficients 
c---------------------------------------------------------------
      subroutine calc_ab(ns,rdat,icors,bn,vb,vn,vx,vv,anf,
     &                    ncx,ncy,ncz,mijks,ipcx,ipcy,ipcz,
     &                    ind,inds,alf1,bet1,alf2,bet2,Em,nu,npb2,ipb2,
     &                    npb4,ipb4,iv,pres,iipore,npores)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      character*30 format211          ! format for pgf95
      integer*4 npb2    ! dimension of the ipb2
      integer*4 npb4    ! dimension of the ipb4
      integer*4 ipb2(4,npb2)
      integer*4 ipb4(6,npb4)

      integer checkstat ! check the success of allocate command
      integer*4 ns ! number of solid points
      real*8    rdat(3,ns) ! elastic solid points coordinates
c      real*8    rvirt(3,ns) ! virtual displacement
      integer*4 icors(3,ns) ! coordinates of the solid points
      real*8    bn(3,9) ! normalized vectors
      real*8    vb(3,9) ! bond vectors (real numbers)
      real*8    vn(3,19) ! discrete velocities normalized
      real*8    vx(3,19) ! xn/|rn|
      real*8    vv(3,19) ! discrete velocities (real numbers)
      real*8    anf(9,48) ! angle plane normal, angular force vectors j k; for angular springs

      real*8 flin(3) ! linear spring force
      real*8 xnj(3),xrj(3),rnj(3),rtj(3),xnk(3),xrk(3),rnk(3),rtk(3) ! force calculation vectors
      real*8 xn(3),rn(3),rt(3) ! vectors in linear spring force calculation
      real*8 dfi ! delta phi, angle change for angular force

      integer*4 ncx ! x unit cell size
      integer*4 ncy ! y unit cell size
      integer*4 ncz ! z unit cell size
      integer*4 mijks(ncx,ncy,ncz)

      integer icv(3,8) ! cubic vectors
      integer icp(3,8) ! cube points

      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2) ! periodic boundary conditions
      integer isc ! check solid cube indicator
      integer ind(ncx,ncy,ncz) ! index file
      integer inds(ncx,ncy,ncz) ! index file

      integer*4 bon(3,24), ang(6,72) ! bonds and angles for a cube
      real*8    sbond(24), abond(72) ! elastic constants
      real*8    sbondin(24), abondin(72) ! elastic constants
      real*8    alf1,bet1              ! elastic constants
      real*8    alf2,bet2

      real*8,    dimension(:,:,:), allocatable :: sigmap ! (+->-) plus stress tensors
      real*8,    dimension(:,:,:), allocatable :: sigmam ! (+->-) minus stress tensors
      real*8,    dimension(:,:,:), allocatable :: strain ! local strain tensor
      real*8 asigmap(3,3),asigmam(3,3),astrain(3,3) ! average tensors
      real*8 sv(3,8) ! cube strain vectors
      real*8 up(3) ! cube point displacement

      real*8 vlayer ! layer volume
      real*8 Em ! Young modulus
      real*8 nu ! Poisson's ratio
      real*8 Cxxxx,Cyyxx,Cxyxy ! stiffness matrix coefficients
      real*8 Exxxx,Eyyxx,Exyxy ! effective stiffness coefficients
      real*8 frc(3)            ! global force condition
      real*8 sxx0,syy0,exx0    ! global stress and strains in the layer
      real*8 vcell             ! cell volume

      real*8 itensor(3,3)      ! identity tensor
      real*8 epsi              ! i-s pore volume
      real*8 alphai(3,3),betai(npores) ! alpha coefficient,beta coefficient
      integer  iv(3,19)        ! discrete velocities (integer numbers)
      real*8 pres              ! fluid pressure
      integer iipore           ! pore filled with fluid
      integer npores           ! number of distinct pores
      integer*4 lp1(3),lp2(3),lp3(3),lp4(3) ! points coordinates

      itensor=0.D0
      itensor(1,1)=1.D0
      itensor(2,2)=1.D0
      itensor(3,3)=1.D0

      Cxxxx = Em*(nu-1.D0)/(2.D0*nu*nu+nu-1.D0) ! stiffness coefficients
      Cyyxx = Em*nu/((1.D0+nu)*(1.D0-2.D0*nu))
      Cxyxy = Em/(2.D0*(1.D0+nu))
      exx0  = 0.0004D0
      vcell = ncx*ncy*ncz

      icv(1,1:8)=(/0,1,0,1,0,1,0,1/) ! cubic vectors
      icv(2,1:8)=(/0,0,1,1,0,0,1,1/)
      icv(3,1:8)=(/0,0,0,0,1,1,1,1/)

      sv(1,1:8)=(/-0.5D0,0.5D0,-0.5D0,0.5D0,-0.5D0,0.5D0,-0.5D0,0.5D0/) ! cube strain vectors
      sv(2,1:8)=(/-0.5D0,-0.5D0,0.5D0,0.5D0,-0.5D0,-0.5D0,0.5D0,0.5D0/)
      sv(3,1:8)=(/-0.5D0,-0.5D0,-0.5D0,-0.5D0,0.5D0,0.5D0,0.5D0,0.5D0/)

      open(1,file='cube_bon')        ! read elementary cube data
      read(1,*)((bon(i,j),i=1,3),j=1,24)
      close(1)
      open(1,file='cube_ang')
      read(1,*)((ang(i,j),i=1,6),j=1,72)
      close(1)
      open(1,file='cube_sbond')
      read(1,*)(sbond(i),i=1,24)
      close(1)
      open(1,file='cube_abond')
      read(1,*)(abond(i),i=1,72)
      close(1)
      sbondin = sbond
      abondin = abond


      open(12,file='ind') ! open medium structure index file (1-pore, 0-solid)
      write(format211,*)'(" ",',ncx,'i1)' ! create format to read from 'ind'
      do k=1,ncz
       do j=1,ncy
        read(12,fmt=format211)(ind(i,j,k),i=1,ncx) ! read structure data from the file
       enddo
      enddo
      close(12)

      ncub = 0
      epsi = 0.D0
      do i=1,ncx
       do j=1,ncy
        do k=1,ncz

         isc=0
         do l=1,8  ! extract cube points
          icp(1,l)=ipcx(i+icv(1,l)+1)
          icp(2,l)=ipcy(j+icv(2,l)+1)
          icp(3,l)=ipcz(k+icv(3,l)+1)
         enddo
         isc=ind(i,j,k)

         if(isc.eq.0.or.isc.eq.3)then ! there is a cube, start calculate stress tensor
          ncub=ncub+1
         endif
         if(isc.eq.iipore)then
          epsi=epsi+1.D0
         endif
        enddo
       enddo
      enddo
      epsi=epsi/vcell


      allocate(sigmap(3,3,ncub),stat=checkstat) ! create sigmap
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sigmap'
       stop
      endif

      allocate(sigmam(3,3,ncub),stat=checkstat) ! create sigmam
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sigmam'
       stop
      endif

      allocate(strain(3,3,ncub),stat=checkstat) ! create strain
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for strain'
       stop
      endif

      open(113,file='alpha_beta',position='append')
      ncub = 0
      sigmap = 0.D0
      sigmam = 0.D0
      strain = 0.D0
      do i=1,ncx
       do j=1,ncy
        do k=1,ncz

         isc=0
         do l=1,8  ! extract cube points
          icp(1,l)=ipcx(i+icv(1,l)+1)
          icp(2,l)=ipcy(j+icv(2,l)+1)
          icp(3,l)=ipcz(k+icv(3,l)+1)
         enddo
         isc=ind(i,j,k)
	   if (isc.eq.0) then
                           sbond=sbondin*alf1
                           abond=abondin*bet1
         elseif (isc.eq.3) then
                           sbond=sbondin*alf2
                           abond=abondin*bet2
         endif

         if(isc.eq.0.or.isc.eq.3)then ! there is a cube, start calculate strain and stress tensors
          ncub=ncub+1

          do l=1,8 ! calculate strain tensor
           do m=1,3
            do n=1,3
             np=mijks(icp(1,l),icp(2,l),icp(3,l)) ! extract point number
             up=rdat(1:3,np)        ! displacement in the point
             strain(m,n,ncub)=strain(m,n,ncub)+sv(m,l)*up(n) ! calculate strain tensor
     &                                        +sv(n,l)*up(m)
            enddo
           enddo
          enddo

          do l=1,24 ! bonds loop to calculate linear springs force
           n1=mijks(icp(1,bon(1,l)),icp(2,bon(1,l)),icp(3,bon(1,l)))
           n2=mijks(icp(1,bon(2,l)),icp(2,bon(2,l)),icp(3,bon(2,l)))
           xn=bn(1:3,bon(3,l)) ! normalized equilibrium i-j vector
           rn=vb(1:3,bon(3,l)) ! not normalized equilibrium i-j vector
           rt=rdat(1:3,n2)-rdat(1:3,n1)+rn ! deformed i-j vector
           flin=sbond(l)*((rt(1)*xn(1)+rt(2)*xn(2)+rt(3)*xn(3))*xn-rn) ! linear spring force
           if(xn(1).gt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)+flin
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)-flin
           endif
           if(xn(1).lt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)-flin
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)+flin
           endif
           if(xn(2).gt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)+flin
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)-flin
           endif
           if(xn(2).lt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)-flin
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)+flin
           endif
           if(xn(3).gt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)+flin
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)-flin
           endif
           if(xn(3).lt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)-flin
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)+flin
           endif
          enddo

          do l=1,72 ! angles loop
           n1=mijks(icp(1,ang(1,l)),icp(2,ang(1,l)),icp(3,ang(1,l)))
           n2=mijks(icp(1,ang(2,l)),icp(2,ang(2,l)),icp(3,ang(2,l)))
           n3=mijks(icp(1,ang(3,l)),icp(2,ang(3,l)),icp(3,ang(3,l)))
           xnj=vn(1:3,ang(4,l)) ! normalized equilibrium i-j vector
           xrj=vx(1:3,ang(4,l)) ! xn/|rn|
           rnj=vv(1:3,ang(4,l)) ! not normalized equilibrium i-j vector
           rtj=rdat(1:3,n2)-rdat(1:3,n1)+rnj ! deformed i-j vector

           xnk=vn(1:3,ang(5,l)) ! normalized equilibrium i-k vector
           xrk=vx(1:3,ang(5,l)) ! xn/|rn|
           rnk=vv(1:3,ang(5,l)) ! not normalized equilibrium i-k vector
           rtk=rdat(1:3,n3)-rdat(1:3,n1)+rnk ! deformed i-k vector

           dfi=((xrk(2)*rtk(3)-xrk(3)*rtk(2)
     &          -xrj(2)*rtj(3)+xrj(3)*rtj(2)) ! angle change delta phi
     &     *anf(1,ang(6,l))
     &     -(xrk(1)*rtk(3)-xrk(3)*rtk(1)-xrj(1)*rtj(3)+xrj(3)*rtj(1))
     &     *anf(2,ang(6,l))
     &     +(xrk(1)*rtk(2)-xrk(2)*rtk(1)-xrj(1)*rtj(2)+xrj(2)*rtj(1))
     &     *anf(3,ang(6,l)))*abond(l)

           if(xnj(1).gt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)-dfi*anf(4:6,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)+dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(1).lt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)+dfi*anf(4:6,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)-dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(2).gt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)-dfi*anf(4:6,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)+dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(2).lt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)+dfi*anf(4:6,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)-dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(3).gt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)-dfi*anf(4:6,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)+dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(3).lt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)+dfi*anf(4:6,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)-dfi*anf(4:6,ang(6,l))
           endif

           if(xnk(1).gt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)-dfi*anf(7:9,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)+dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(1).lt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)+dfi*anf(7:9,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)-dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(2).gt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)-dfi*anf(7:9,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)+dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(2).lt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)+dfi*anf(7:9,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)-dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(3).gt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)-dfi*anf(7:9,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)+dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(3).lt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)+dfi*anf(7:9,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)-dfi*anf(7:9,ang(6,l))
           endif
          enddo

c          write(113,*)'ncub   = ',ncub
c          write(113,*)'ijk = ',i,j,k
c          write(113,*)'sigmap = '
c          write(113,*)sigmap(1:3,1:3,ncub)
c          write(113,*)'sigmam = '
c          write(113,*)sigmam(1:3,1:3,ncub)
c          write(113,*)'strain = '
c          write(113,*)strain(1:3,1:3,ncub)*0.25D0
         endif

        enddo
       enddo
      enddo
      strain=strain*0.25D0

1984  format(9(1X,E15.8))

      asigmap = 0.D0
      asigmam = 0.D0
      astrain = 0.D0
      do i=1,ncub
       asigmap = asigmap + sigmap(1:3,1:3,i)
       asigmam = asigmam + sigmam(1:3,1:3,i)
       astrain = astrain + strain(1:3,1:3,i)
      enddo
      rncub = ncub

      alphai=-itensor*epsi+asigmap/vcell/pres ! alphai tensor calculation

c      betai = 0.D0
c      do i=1,npb4
c
c       up=(rdat(1:3,ipb4(3,i))+rdat(1:3,ipb4(4,i))
c     &    +rdat(1:3,ipb4(5,i))+rdat(1:3,ipb4(6,i)))*0.25D0
c
c       betai=betai
c     & +up(1)*vv(1,ipb4(2,i))
c     & +up(2)*vv(2,ipb4(2,i))
c     & +up(3)*vv(3,ipb4(2,i))
c      enddo
c      betai=betai/vcell/pres

c start betai calculation
      betai=0.D0
      do iip=1,npores  ! cycle by distinct pores
       
      do k=1,ncz
       do j=1,ncy
        do i=1,ncx
         if(ind(i,j,k).eq.iip)then ! are in the pore iip
          do l=2,7
           nx=ipcx(i+iv(1,l)+1)   ! apply periodic conditions
           ny=ipcy(j+iv(2,l)+1)   ! apply periodic conditions
           nz=ipcz(k+iv(3,l)+1)   ! apply periodic conditions
           if(ind(nx,ny,nz).eq.0)then  ! surface face is found
            if(iv(1,l).ne.0)then
             lp1=(/i+(iv(1,l)+1)/2,j+0,k+0/)
             lp2=(/i+(iv(1,l)+1)/2,j+1,k+0/)
             lp3=(/i+(iv(1,l)+1)/2,j+0,k+1/)
             lp4=(/i+(iv(1,l)+1)/2,j+1,k+1/)

             lp1(1)=ipcx(lp1(1)+1)
             lp1(2)=ipcy(lp1(2)+1)
             lp1(3)=ipcz(lp1(3)+1)
             lp2(1)=ipcx(lp2(1)+1)
             lp2(2)=ipcy(lp2(2)+1)
             lp2(3)=ipcz(lp2(3)+1)
             lp3(1)=ipcx(lp3(1)+1)
             lp3(2)=ipcy(lp3(2)+1)
             lp3(3)=ipcz(lp3(3)+1)
             lp4(1)=ipcx(lp4(1)+1)
             lp4(2)=ipcy(lp4(2)+1)
             lp4(3)=ipcz(lp4(3)+1)
            elseif(iv(2,l).ne.0)then
             lp1=(/i+0,j+(iv(2,l)+1)/2,k+0/)
             lp2=(/i+1,j+(iv(2,l)+1)/2,k+0/)
             lp3=(/i+0,j+(iv(2,l)+1)/2,k+1/)
             lp4=(/i+1,j+(iv(2,l)+1)/2,k+1/)

             lp1(1)=ipcx(lp1(1)+1)
             lp1(2)=ipcy(lp1(2)+1)
             lp1(3)=ipcz(lp1(3)+1)
             lp2(1)=ipcx(lp2(1)+1)
             lp2(2)=ipcy(lp2(2)+1)
             lp2(3)=ipcz(lp2(3)+1)
             lp3(1)=ipcx(lp3(1)+1)
             lp3(2)=ipcy(lp3(2)+1)
             lp3(3)=ipcz(lp3(3)+1)
             lp4(1)=ipcx(lp4(1)+1)
             lp4(2)=ipcy(lp4(2)+1)
             lp4(3)=ipcz(lp4(3)+1)
            elseif(iv(3,l).ne.0)then
             lp1=(/i+0,j+0,k+(iv(3,l)+1)/2/)
             lp2=(/i+1,j+0,k+(iv(3,l)+1)/2/)
             lp3=(/i+0,j+1,k+(iv(3,l)+1)/2/)
             lp4=(/i+1,j+1,k+(iv(3,l)+1)/2/)

             lp1(1)=ipcx(lp1(1)+1)
             lp1(2)=ipcy(lp1(2)+1)
             lp1(3)=ipcz(lp1(3)+1)
             lp2(1)=ipcx(lp2(1)+1)
             lp2(2)=ipcy(lp2(2)+1)
             lp2(3)=ipcz(lp2(3)+1)
             lp3(1)=ipcx(lp3(1)+1)
             lp3(2)=ipcy(lp3(2)+1)
             lp3(3)=ipcz(lp3(3)+1)
             lp4(1)=ipcx(lp4(1)+1)
             lp4(2)=ipcy(lp4(2)+1)
             lp4(3)=ipcz(lp4(3)+1)
            endif
            n3=mijks(lp1(1),lp1(2),lp1(3))
            n4=mijks(lp2(1),lp2(2),lp2(3))
            n5=mijks(lp3(1),lp3(2),lp3(3))
            n6=mijks(lp4(1),lp4(2),lp4(3))

            up=(rdat(1:3,n3)+rdat(1:3,n4)
     &      +rdat(1:3,n5)+rdat(1:3,n6))*0.25D0

            betai(iip)=betai(iip)
     &      -up(1)*vv(1,l)
     &      -up(2)*vv(2,l)
     &      -up(3)*vv(3,l)
           endif
          enddo
         endif
        enddo
       enddo
      enddo
      enddo
      betai=betai/vcell/pres
! end betai calculation

      write(113,*)'Elastic medium properties'
      write(113,*)'Ypung modulus Em = ',Em
      write(113,*)'Poisson ratio nu = ',nu
      write(113,*)'Stiffness coefficients'
      write(113,*)'C_xxxx = ',Cxxxx
      write(113,*)'C_yyxx = ',Cyyxx
      write(113,*)'C_xyxy = ',Cxyxy
      write(113,*)'Simulation parameters'
      write(113,*)'Cell volume vcell = ',vcell
      write(113,*)'Solid part volume(elementary cubes) rncub = ',rncub
      write(113,*)'Simulation results'
      write(113,*)'averaged stress tensor'
      write(113,*)'asigmap = '
      write(113,*)asigmap/rncub
      write(113,*)'asigmam = '
      write(113,*)asigmam/rncub
      write(113,*)'averaged strain'
      write(113,*)'astrain = '
      write(113,*)astrain/rncub
      write(113,*)'epsi = ',epsi
      write(113,*)'alphai = '
      write(113,*)alphai
      write(113,*)'betai  = '
      write(113,*)betai
      write(113,*)'pres = ',pres
      close(113)

      deallocate(sigmap,sigmam,strain)

      return
      end
c---------------------------------------------------------------
c calculate stress, strain tensors
c---------------------------------------------------------------
      subroutine calc_stress(ns,rdat,icors,bn,vb,vn,vx,vv,anf,
     &                    ncx,ncy,ncz,mijks,ipcx,ipcy,ipcz,
     &                    ind,inds,alf1,bet1,alf2,bet2,Em,nu)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      integer checkstat ! check the success of allocate command
      integer*4 ns ! number of solid points
      real*8    rdat(3,ns) ! elastic solid points coordinates
c      real*8    rvirt(3,ns) ! virtual displacement
      integer*4 icors(3,ns) ! coordinates of the solid points
      real*8    bn(3,9) ! normalized vectors
      real*8    vb(3,9) ! bond vectors (real numbers)
      real*8    vn(3,19) ! discrete velocities normalized
      real*8    vx(3,19) ! xn/|rn|
      real*8    vv(3,19) ! discrete velocities (real numbers)
      real*8    anf(9,48) ! angle plane normal, angular force vectors j k; for angular springs

      real*8 flin(3) ! linear spring force
      real*8 xnj(3),xrj(3),rnj(3),rtj(3),xnk(3),xrk(3),rnk(3),rtk(3) ! force calculation vectors
      real*8 xn(3),rn(3),rt(3) ! vectors in linear spring force calculation
      real*8 dfi ! delta phi, angle change for angular force

      integer*4 ncx ! x unit cell size
      integer*4 ncy ! y unit cell size
      integer*4 ncz ! z unit cell size
      integer*4 mijks(ncx,ncy,ncz)

      integer icv(3,8) ! cubic vectors
      integer icp(3,8) ! cube points

      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2) ! periodic boundary conditions
      integer isc ! check solid cube indicator
      integer ind(ncx,ncy,ncz) ! index file
      integer inds(ncx,ncy,ncz) ! index file

      integer*4 bon(3,24), ang(6,72) ! bonds and angles for a cube
      real*8    sbond(24), abond(72) ! elastic constants
      real*8    sbondin(24), abondin(72) ! elastic constants
      real*8    alf1,bet1              ! elastic constants
      real*8    alf2,bet2	 
      real*8,    dimension(:,:,:), allocatable :: sigmap ! (+->-) plus stress tensors
      real*8,    dimension(:,:,:), allocatable :: sigmam ! (+->-) minus stress tensors
      real*8,    dimension(:,:,:), allocatable :: strain ! local strain tensor
      real*8 asigmap(3,3),asigmam(3,3),astrain(3,3) ! average tensors
      real*8 sv(3,8) ! cube strain vectors
      real*8 up(3) ! cube point displacement

      real*8 vlayer ! layer volume
      real*8 Em ! Young modulus
      real*8 nu ! Poisson's ratio
      real*8 Cxxxx,Cyyxx,Cxyxy ! stiffness matrix coefficients
      real*8 Exxxx,Eyyxx,Exyxy ! effective stiffness coefficients
      real*8 frc(3)            ! global force condition
      real*8 sxx0,syy0,exx0    ! global stress and strains in the layer
      real*8 vcell             ! cell volume

      Cxxxx = Em*(nu-1.D0)/(2.D0*nu*nu+nu-1.D0) ! stiffness coefficients
      Cyyxx = Em*nu/((1.D0+nu)*(1.D0-2.D0*nu))
      Cxyxy = Em/(2.D0*(1.D0+nu))
      exx0  = 0.0004D0
      vcell = ncx*ncy*ncz

      icv(1,1:8)=(/0,1,0,1,0,1,0,1/) ! cubic vectors
      icv(2,1:8)=(/0,0,1,1,0,0,1,1/)
      icv(3,1:8)=(/0,0,0,0,1,1,1,1/)

      sv(1,1:8)=(/-0.5D0,0.5D0,-0.5D0,0.5D0,-0.5D0,0.5D0,-0.5D0,0.5D0/) ! cube strain vectors
      sv(2,1:8)=(/-0.5D0,-0.5D0,0.5D0,0.5D0,-0.5D0,-0.5D0,0.5D0,0.5D0/)
      sv(3,1:8)=(/-0.5D0,-0.5D0,-0.5D0,-0.5D0,0.5D0,0.5D0,0.5D0,0.5D0/)

      open(1,file='cube_bon')        ! read elementary cube data
      read(1,*)((bon(i,j),i=1,3),j=1,24)
      close(1)
      open(1,file='cube_ang')
      read(1,*)((ang(i,j),i=1,6),j=1,72)
      close(1)
      open(1,file='cube_sbond')
      read(1,*)(sbond(i),i=1,24)
      close(1)
      open(1,file='cube_abond')
      read(1,*)(abond(i),i=1,72)
      close(1)
      sbondin = sbond
      abondin = abond


      ncub = 0
      do i=1,ncx
       do j=1,ncy
        do k=1,ncz

         isc=0
         do l=1,8  ! extract cube points
          icp(1,l)=ipcx(i+icv(1,l)+1)
          icp(2,l)=ipcy(j+icv(2,l)+1)
          icp(3,l)=ipcz(k+icv(3,l)+1)
         enddo
         isc=ind(i,j,k)

         if(isc.eq.0.or.isc.eq.3)then ! there is a cube, start calculate stress tensor
          ncub=ncub+1
         endif
        enddo
       enddo
      enddo

      allocate(sigmap(3,3,ncub),stat=checkstat) ! create sigmap
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sigmap'
       stop
      endif

      allocate(sigmam(3,3,ncub),stat=checkstat) ! create sigmam
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for sigmam'
       stop
      endif

      allocate(strain(3,3,ncub),stat=checkstat) ! create strain
      if(checkstat>0) then
       write(*,*)'ERROR! impossible to allocate memory for strain'
       stop
      endif

      open(113,file='stress_tensor',position='append')
      open(333,file='strain')
      open(666,file='stress')
      ncub = 0
      sigmap = 0.D0
      sigmam = 0.D0
      strain = 0.D0
      do i=1,ncx
       do j=1,ncy
        do k=1,ncz

         isc=0
         do l=1,8  ! extract cube points
          icp(1,l)=ipcx(i+icv(1,l)+1)
          icp(2,l)=ipcy(j+icv(2,l)+1)
          icp(3,l)=ipcz(k+icv(3,l)+1)
         enddo
         isc=ind(i,j,k)
		  if (isc.eq.0) then
                           sbond=sbondin*alf1
                           abond=abondin*bet1
         elseif (isc.eq.3) then
                           sbond=sbondin*alf2
                           abond=abondin*bet2
         endif
         if(isc.eq.0.or.isc.eq.3)then ! there is a cube, start calculate strain and stress tensors
          ncub=ncub+1

          do l=1,8 ! calculate strain tensor
           do m=1,3
            do n=1,3
             np=mijks(icp(1,l),icp(2,l),icp(3,l)) ! extract point number
             up=rdat(1:3,np)        ! displacement in the point
             strain(m,n,ncub)=strain(m,n,ncub)+sv(m,l)*up(n) ! calculate strain tensor
     &                                        +sv(n,l)*up(m)
            enddo
           enddo
          enddo

          do l=1,24 ! bonds loop to calculate linear springs force
           n1=mijks(icp(1,bon(1,l)),icp(2,bon(1,l)),icp(3,bon(1,l)))
           n2=mijks(icp(1,bon(2,l)),icp(2,bon(2,l)),icp(3,bon(2,l)))
           xn=bn(1:3,bon(3,l)) ! normalized equilibrium i-j vector
           rn=vb(1:3,bon(3,l)) ! not normalized equilibrium i-j vector
           rt=rdat(1:3,n2)-rdat(1:3,n1)+rn ! deformed i-j vector
           flin=sbond(l)*((rt(1)*xn(1)+rt(2)*xn(2)+rt(3)*xn(3))*xn-rn) ! linear spring force

           if(xn(1).gt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)+flin
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)-flin
           endif
           if(xn(1).lt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)-flin
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)+flin
           endif
           if(xn(2).gt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)+flin
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)-flin
           endif
           if(xn(2).lt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)-flin
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)+flin
           endif
           if(xn(3).gt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)+flin
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)-flin
           endif
           if(xn(3).lt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)-flin
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)+flin
           endif
          enddo

          do l=1,72 ! angles loop
           n1=mijks(icp(1,ang(1,l)),icp(2,ang(1,l)),icp(3,ang(1,l)))
           n2=mijks(icp(1,ang(2,l)),icp(2,ang(2,l)),icp(3,ang(2,l)))
           n3=mijks(icp(1,ang(3,l)),icp(2,ang(3,l)),icp(3,ang(3,l)))
           xnj=vn(1:3,ang(4,l)) ! normalized equilibrium i-j vector
           xrj=vx(1:3,ang(4,l)) ! xn/|rn|
           rnj=vv(1:3,ang(4,l)) ! not normalized equilibrium i-j vector
           rtj=rdat(1:3,n2)-rdat(1:3,n1)+rnj ! deformed i-j vector

           xnk=vn(1:3,ang(5,l)) ! normalized equilibrium i-k vector
           xrk=vx(1:3,ang(5,l)) ! xn/|rn|
           rnk=vv(1:3,ang(5,l)) ! not normalized equilibrium i-k vector
           rtk=rdat(1:3,n3)-rdat(1:3,n1)+rnk ! deformed i-k vector

           dfi=((xrk(2)*rtk(3)-xrk(3)*rtk(2)
     &          -xrj(2)*rtj(3)+xrj(3)*rtj(2)) ! angle change delta phi
     &     *anf(1,ang(6,l))
     &     -(xrk(1)*rtk(3)-xrk(3)*rtk(1)-xrj(1)*rtj(3)+xrj(3)*rtj(1))
     &     *anf(2,ang(6,l))
     &     +(xrk(1)*rtk(2)-xrk(2)*rtk(1)-xrj(1)*rtj(2)+xrj(2)*rtj(1))
     &     *anf(3,ang(6,l)))*abond(l)

           if(xnj(1).gt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)-dfi*anf(4:6,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)+dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(1).lt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)+dfi*anf(4:6,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)-dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(2).gt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)-dfi*anf(4:6,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)+dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(2).lt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)+dfi*anf(4:6,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)-dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(3).gt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)-dfi*anf(4:6,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)+dfi*anf(4:6,ang(6,l))
           endif
           if(xnj(3).lt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)+dfi*anf(4:6,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)-dfi*anf(4:6,ang(6,l))
           endif

           if(xnk(1).gt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)-dfi*anf(7:9,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)+dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(1).lt.0)then
            sigmap(1:3,1,ncub)=sigmap(1:3,1,ncub)+dfi*anf(7:9,ang(6,l))
            sigmam(1:3,1,ncub)=sigmam(1:3,1,ncub)-dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(2).gt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)-dfi*anf(7:9,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)+dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(2).lt.0)then
            sigmap(1:3,2,ncub)=sigmap(1:3,2,ncub)+dfi*anf(7:9,ang(6,l))
            sigmam(1:3,2,ncub)=sigmam(1:3,2,ncub)-dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(3).gt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)-dfi*anf(7:9,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)+dfi*anf(7:9,ang(6,l))
           endif
           if(xnk(3).lt.0)then
            sigmap(1:3,3,ncub)=sigmap(1:3,3,ncub)+dfi*anf(7:9,ang(6,l))
            sigmam(1:3,3,ncub)=sigmam(1:3,3,ncub)-dfi*anf(7:9,ang(6,l))
           endif
          enddo

c          write(113,*)'ncub   = ',ncub
c          write(113,*)'ijk = ',i,j,k
c          write(113,*)'sigmap = '
c          write(113,*)sigmap(1:3,1:3,ncub)
c          write(113,*)'sigmam = '
c          write(113,*)sigmam(1:3,1:3,ncub)
c          write(113,*)'strain = '
c          write(113,*)strain(1:3,1:3,ncub)*0.25D0

c          write(333,1984)strain(1:3,1,ncub)*0.25D0,
c     &                strain(1:3,2,ncub)*0.25D0,
c     &                strain(1:3,3,ncub)*0.25D0

c          write(666,1984)sigmap(1:3,1,ncub),
c     &                sigmap(1:3,2,ncub),
c     &                sigmap(1:3,3,ncub)


         else
c          write(333,1984)0.D0,0.D0,0.D0,0.D0,0.D0,0.D0,0.D0,0.D0,0.D0
c          write(666,1984)0.D0,0.D0,0.D0,0.D0,0.D0,0.D0,0.D0,0.D0,0.D0
         endif

        enddo
       enddo
      enddo
      strain=strain*0.25D0

      close(333)
      close(666)
1984  format(9(1X,E15.8))

      asigmap = 0.D0
      asigmam = 0.D0
      astrain = 0.D0
      do i=1,ncub
       asigmap = asigmap + sigmap(1:3,1:3,i)
       asigmam = asigmam + sigmam(1:3,1:3,i)
       astrain = astrain + strain(1:3,1:3,i)
      enddo
      rncub = ncub

c      rncx=ncx-2
c      Exxxx=asigmap(1,1)/(vcell*exx0/rncx)
c      Eyyxx=asigmap(2,2)/(vcell*exx0/rncx)

      write(113,*)'Elastic medium properties'
      write(113,*)'Ypung modulus Em = ',Em
      write(113,*)'Poisson ratio nu = ',nu
      write(113,*)'Stiffness coefficients'
      write(113,*)'C_xxxx = ',Cxxxx
      write(113,*)'C_yyxx = ',Cyyxx
      write(113,*)'C_xyxy = ',Cxyxy
      write(113,*)'Simulation parameters'
      write(113,*)'Cell volume vcell = ',vcell
      write(113,*)'Solid part volume(elementary cubes) rncub = ',rncub
c      write(113,*)'Layer volume (elementary cubes) vlayer = ',vlayer
c      write(113,*)'Force per elementary cube vertex frc = ',frc
c      write(113,*)'Global strain exx0 = ',exx0
c      write(113,*)'Stress imposed on the layer sxx0 = ',sxx0
c      write(113,*)'Stress imposed on the layer syy0 = ',syy0
      write(113,*)'Simulation results'
      write(113,*)'averaged stress tensor'
      write(113,*)'asigmap = '
      write(113,*)asigmap/rncub
      write(113,*)'asigmam = '
      write(113,*)asigmam/rncub
      write(113,*)'averaged strain'
      write(113,*)'astrain = '
      write(113,*)astrain/rncub
c      write(113,*)'Effective stiffness coefficients'
c      write(113,*)'Exxxx = ',Exxxx
c      write(113,*)'Eyyxx = ',Eyyxx
      close(113)

      deallocate(sigmap,sigmam,strain)

      return
      end
c___________________________________________________
c     Interpolation rule LBM 
c 
c___________________________________________________
      subroutine interpolationrule(ipcx,ipcy,ipcz,ind,c1d6,c1d12,
     &  c5d399,c19d399,
     &  c11d2394,c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72,
     &  c1d24,tr1,tr2,tr3,tb1,tb2,tb3,itm,itw,nl,fr,fb,ee,bfr,
     &  bfb,ncx,ncy,ncz,mijk,sig,wet,Sr,Sb,cb2,cr2,icor,
     &  svr,svb,B,nps,ips,npb,ipb,iv,niv,idir,t0,
     &  lsize,rr0,rb0,eps,its,itms,ns,rdat,vdat,dt,adat,icors,
     &  nbo,bn,bon,bx,vb,alf1,bet1,alf2,bet2,
     &  nna,vn,ang,vx,vv,anf,rsi,mijks)

      implicit  real*8 (a-h,o-z)
      implicit  integer*4 (i-n)

      real*8 fr(19,nl),fb(19,nl)
      real*8 bfr(3),bfb(3)
      real*8 Sr(19),Sb(19)
      integer*4 ncx,ncy,ncz
      integer*4 nl     ! real number of the liquid points
      integer*4 nps    ! dimension of the ips
      integer*4 npb    ! dimension of the ipb
c      integer*4 npm    ! dimension of the ipm
      integer*4 mijk(ncx,ncy,ncz)
      integer*4 icor(3,nl)
      integer*4 ips(3,nps)
      integer*4 ipb(3,npb)
c      integer*4 ipm(4,npm)
      integer   iv(3,19)          ! discrete velocities
      integer   niv(19)           ! numbers of the opposite velocities
      real*8 vir        ! red fluid viscosity
      real*8 vib        ! blue fluid viscosity

      real*8 Fpr(19),Fpb(19)
      real*8 pcfr(19,nl),pcfb(19,nl)  ! can be created here
      real*8 rr(nl),rb(nl),cf(nl)

      character*8  date               ! current date
      character*10 time               ! current time
      integer*4 ic(3)
      real*8 Cg(3)                    ! color gradient
      real*8 Fs(3)
      real*8 f(19)
      real*8 ri
      real*8 ci2,svi,bfi(3),Si(19),Fpi(19)
      real*8 pcf(19)
      real*8 cosf(18)
c     real*8  iv2(3,18),cn(18)
      real*8  cn ! norm inverse

      real*8  permro,permbo           ! old permeability values for convergance test
      integer istop                   ! check for quit
      real*8 ti1,ti2,ti3
      real*8 c1d6,c1d12,c5d399,c19d399
      real*8 c11d2394,c1d63,c1d18,c1d36
      real*8 c4d1197,c1d252,c1d72,c1d24
      real*8 tr1,tr2,tr3,tb1,tb2,tb3
      real*8 rk(19)
      integer ind(ncx,ncy,ncz)    ! unit cell: 1-pore, 0-solid
      integer ipcx(ncx+2),ipcy(ncy+2),ipcz(ncz+2)
      integer itms

      integer*4 ns ! number of solid points
      real*8    rdat(3,ns) ! elastic solid points coordinates
      real*8    vdat(3,ns) ! elastic solid points velocity
      real*8    dt,dti,dt2 ! time step, timestep inverse, time step square
      real*8    adat(3,ns) ! elastic solid points acceleration
      integer*4 icors(3,ns) ! coordinates of the solid points
      integer*8 nbo ! bonds counter
      real*8    bn(3,9) ! normalized vectors
      integer*4 bon(3,nbo)     ! bonds
      real*8    bx(3,9) ! xn/|rn|
      real*8    vb(3,9) ! bond vectors (real numbers)
      real*8    alf1,bet1              ! elastic constants^M
      real*8    alf2,bet2

      integer*8 nna ! angles counter
      real*8    vn(3,19) ! discrete velocities normalized
      integer*4 ang(6,nna) !angles array
      real*8    vx(3,19) ! xn/|rn|
      real*8    vv(3,19) ! discrete velocities (real numbers)
      real*8    anf(9,48) ! angle plane normal, angular force vectors j k; for angular springs
      real*8    rsi ! inverse of solid body density
      real*8    ubc ! solid boundary point velocity projection
      real*8    ti(19)
      integer*4 mijks(ncx,ncy,ncz)
      real*8 rsdti2

      dti=1.D0/dt
      rsdti2=rsi*dti*dti
      dt2=dt*dt
      vir=dti*(1.D0/svr-0.5D0)/3.D0  ! red fluid viscosity
      vib=dti*(1.D0/svb-0.5D0)/3.D0  ! blue fluid viscosity

      permro=0.D0               ! initialize permeability
      permbo=0.D0               ! initialize permeability
      istop=0                   ! initialize istop
      is = 0                    ! check for save index

      rk=(/1.D0,(c1d6,i=1,6),(c1d12,i=1,12)/) ! calculated once
      Fpr=rk*matmul(transpose(vv),bfr)*dt2   ! red fluid body force projections
      Fpb=rk*matmul(transpose(vv),bfb)*dt2   ! blue fluid body force projections
c      iv2=iv(1:3,2:19) ! discrete velocities for anti-diffusion sheme
c      do i=1,18        ! calculate discrete velocities norms
c       cn(i)=sqrt(dot_product(iv2(1:3,i),iv2(1:3,i)))
c      enddo
       cn = 1.D0/sqrt(2.D0) ! velocity vector norm inverse

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nl,rr,fr,rb,fb,cf)
        do i=1,nl                          ! calculate color and density fields and interface
         rr(i)=fr(1,i)+fr(2,i)+fr(3,i)+fr(4,i)+fr(5,i)+fr(6,i)+fr(7,i)
     &        +fr(8,i)+fr(9,i)+fr(10,i)+fr(11,i)+fr(12,i)+fr(13,i)
     &        +fr(14,i)+fr(15,i)+fr(16,i)+fr(17,i)+fr(18,i)+fr(19,i)
         rb(i)=fb(1,i)+fb(2,i)+fb(3,i)+fb(4,i)+fb(5,i)+fb(6,i)+fb(7,i)
     &        +fb(8,i)+fb(9,i)+fb(10,i)+fb(11,i)+fb(12,i)+fb(13,i)
     &        +fb(14,i)+fb(15,i)+fb(16,i)+fb(17,i)+fb(18,i)+fb(19,i)
         cf(i)=(rr(i)-rb(i))/(rr(i)+rb(i)) ! color field
        enddo
!$OMP END PARALLEL DO

      do it1=itms,itm          ! main iteration circle
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'start parallel region = ',time
       is=is+1
       do it2=1,itw         ! intermediate iteration circle

c        pcfr=0              ! set post-collision matrix to zero
c        pcfb=0              ! set post-collision matrix to zero

! Attention !!! fr(1,i) and fb(1,i) will be changed => passed fr and fr not correct
!!! discrete zero velocity is not propagated

!$OMP  PARALLEL DO DEFAULT(NONE)
!$OMP& PRIVATE(i,j,ll,bfr,Fpr,Sr,bfb,Fpb,Sb,ipcx,ipcy,ipcz)
!$OMP& PRIVATE(ic,ncx,ncy,ncz,Cg,Fs,f,ri,ci2,cb2)
!$OMP& PRIVATE(svi,bfi,Si,Fpi,pcf,cosf,cn)
!$OMP& PRIVATE(c1d6,c1d12,c5d399,c19d399,c11d2394)
!$OMP& PRIVATE(c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72)
!$OMP& PRIVATE(c1d24,tr1,tr2,tr3,tb1,tb2,tb3,ti1,ti2,ti3)
!$OMP& FIRSTPRIVATE(c1d6,c1d12,c5d399,c19d399,c11d2394)
!$OMP& FIRSTPRIVATE(c1d63,c1d18,c1d36,c4d1197,c1d252,c1d72)
!$OMP& FIRSTPRIVATE(c1d24,tr1,tr2,tr3,tb1,tb2,tb3)
!$OMP& FIRSTPRIVATE(bfr,Fpr,Sr,bfb,Fpb,Sb,ipcx,ipcy,ipcz)
!$OMP& FIRSTPRIVATE(ncx,ncy,ncz,cb2,cn)
!$OMP& FIRSTPRIVATE(dt,dti,dt2)
!$OMP& SHARED(nl,rb,fr,pcfr,rr,pcfb,fb,icor,mijk,cf)
!$OMP& SHARED(ee,sig,wet,cr2,svr,svb,B,ind)
        do i=1,nl                     ! collision step (red fluid is dominant)
         if(rb(i)<=ee) then           ! red or blue bulk fluid
          call collision(tr1,tr2,tr3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         fr(1:19,i),pcfr(1:19,i),rr(i),bfr,Fpr,Sr,dt,dti,dt2)
          fb(1,i)=tb1*rb(i)
          pcfb(2:19,i)=(/(tb2*rb(i),j=1,6),(tb3*rb(i),j=1,12)/)
c         pcfb(1:19,i)=(/tb1*rb(i),(tb2*rb(i),j=1,6),(tb3*rb(i),j=1,12)/)
c          call fequil(rk,tb,rb(i),bfb,fb(1:19,i),pcfb(1:19,i))
         elseif(rr(i)<=ee) then
          call collision(tb1,tb2,tb3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         fb(1:19,i),pcfb(1:19,i),rb(i),bfb,Fpb,Sb,dt,dti,dt2)
          fr(1,i)=tr1*rr(i)
          pcfr(2:19,i)=(/(tr2*rr(i),j=1,6),(tr3*rr(i),j=1,12)/)
c         pcfr(1:19,i)=(/tr1*rr(i),(tr2*rr(i),j=1,6),(tr3*rr(i),j=1,12)/)
c          call fequil(rk,tr,rr(i),bfr,fr(1:19,i),pcfr(1:19,i))
         else
          ic=icor(1:3,i)                                       ! interface point coordinates
          call calcFs(ipcx,ipcy,ipcz,ind,mijk,ncx,ncy,ncz,cf,nl,ic
     &         ,Cg,Fs,sig,wet) ! surface tension force
          f=fr(1:19,i)+fb(1:19,i)                ! calculate common particles distribution
          ri=rr(i)+rb(i)                         ! fluid density at interface
          ci2=(cr2*rr(i)+cb2*rb(i))/ri           ! interface sound speed
          ti1=1.D0-2.D0*ci2*dt2
          ti2=ci2*c1d6*dt2
          ti3=ci2*c1d12*dt2 ! interface lattice weights
          svi=(svr*rr(i)+svb*rb(i))/ri     ! viscosity related interface eigen value
          bfi=(bfr*rr(i)+bfb*rb(i))/ri+Fs  ! interface body force
          call collmatrTRT(svi,Si)         ! create interface collision vector
          Fpi(1)=0.D0                      ! body force projections
          Fpi(2)= c1d6*bfi(1)*dt2
          Fpi(3)=-Fpi(2)
          Fpi(4)= c1d6*bfi(2)*dt2
          Fpi(5)=-Fpi(4)
          Fpi(6)= c1d6*bfi(3)*dt2
          Fpi(7)=-Fpi(6)
          Fpi(8)= c1d12*(bfi(1)+bfi(2))*dt2
          Fpi(9)= c1d12*(-bfi(1)+bfi(2))*dt2
          Fpi(10)= -Fpi(9)
          Fpi(11)= -Fpi(8)
          Fpi(12)= c1d12*(bfi(1)+bfi(3))*dt2
          Fpi(13)= c1d12*(-bfi(1)+bfi(3))*dt2
          Fpi(14)= -Fpi(13)
          Fpi(15)= -Fpi(12)
          Fpi(16)= c1d12*(bfi(2)+bfi(3))*dt2
          Fpi(17)= c1d12*(-bfi(2)+bfi(3))*dt2
          Fpi(18)= -Fpi(17)
          Fpi(19)= -Fpi(16)

          call collision(ti1,ti2,ti3,c1d6,c1d12,
     &         c1d18,c19d399,c1d24,c1d36,c1d63,c1d72,
     &         c5d399,c11d2394,c1d252,c4d1197,
     &         f,pcf,ri,bfi,Fpi,Si,dt,dti,dt2)

c         cosf=matmul(Cg,iv2)/cn                   ! cos for anti-diffusion
          cosf(1)= Cg(1)
          cosf(2)=-cosf(1)
          cosf(3)= Cg(2)
          cosf(4)=-cosf(3)
          cosf(5)= Cg(3)
          cosf(6)=-cosf(5)
          cosf(7)= (Cg(1)+Cg(2))*cn
          cosf(8)= (-Cg(1)+Cg(2))*cn
          cosf(9)= -cosf(8)
          cosf(10)= -cosf(7)
          cosf(11)= (Cg(1)+Cg(3))*cn
          cosf(12)= (-Cg(1)+Cg(3))*cn
          cosf(13)= -cosf(12)
          cosf(14)= -cosf(11)
          cosf(15)= (Cg(2)+Cg(3))*cn
          cosf(16)= (-Cg(2)+Cg(3))*cn
          cosf(17)= -cosf(16)
          cosf(18)= -cosf(15)

c          pcfr(1,i)=pcf(1)*rr(i)/ri           ! zero velocity segregation
c          pcfb(1,i)=pcf(1)*rb(i)/ri           ! zero velocity segregation
          fr(1,i)=f(1)*rr(i)/ri                ! zero velocity segregation
          fb(1,i)=f(1)*rb(i)/ri                ! zero velocity segregation

          do ll=2,7
           pcfr(ll,i)=(pcf(ll)+B*ti2*cosf(ll-1)*rb(i))*rr(i)/ri ! anti-diffusion
           pcfb(ll,i)=(pcf(ll)-B*ti2*cosf(ll-1)*rr(i))*rb(i)/ri ! anti-diffusion
          enddo
          do ll=8,19
           pcfr(ll,i)=(pcf(ll)+B*ti3*cosf(ll-1)*rb(i))*rr(i)/ri ! anti-diffusion
           pcfb(ll,i)=(pcf(ll)-B*ti3*cosf(ll-1)*rr(i))*rb(i)/ri ! anti-diffusion
          enddo

         endif
        enddo
!$OMP END PARALLEL DO

c        fr=0   ! set to zero red fluid matrix
c        fb=0   ! set to zero blue fluid matrix

c!$OMP  PARALLEL DO PRIVATE(i)
c!$OMP& SHARED(nl,fr,pcfr,fb,pcfb)
c        do i=1,nl            ! it works correct - full substitution fr by pcfr and fb by pcfb
c         fr(1,i)=pcfr(1,i)   ! zero velocity component redifinition
c         fb(1,i)=pcfb(1,i)
c        enddo
c!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nps,ips,fr,pcfr,fb,pcfb)
        do i=1,nps                                ! simple propagation
         fr(ips(3,i),ips(2,i))=pcfr(ips(3,i),ips(1,i))
         fb(ips(3,i),ips(2,i))=pcfb(ips(3,i),ips(1,i))
        enddo
!$OMP END PARALLEL DO

c!$OMP  PARALLEL DO PRIVATE(i)
c!$OMP& SHARED(npb,ipb,niv,fr,pcfr,fb,pcfb)
c        do i=1,npb                                ! bounce back boundary condition
c         fr(ipb(2,i),ipb(1,i))=pcfr(niv(ipb(2,i)),ipb(1,i))
c         fb(ipb(2,i),ipb(1,i))=pcfb(niv(ipb(2,i)),ipb(1,i))
c        enddo
c!$OMP END PARALLEL DO

        do i=1,npb ! LSM-LBM coupling - boundary
         ubc=(vdat(1,ipb(3,i))*vv(1,ipb(2,i))
     &   +vdat(2,ipb(3,i))*vv(2,ipb(2,i))
     &   +vdat(3,ipb(3,i))*vv(3,ipb(2,i)))*dt

         fr(ipb(2,i),ipb(1,i))=pcfr(niv(ipb(2,i)),ipb(1,i))
     &   +2.D0*rk(ipb(2,i))*rr(ipb(1,i))*ubc
         fb(ipb(2,i),ipb(1,i))=pcfb(niv(ipb(2,i)),ipb(1,i))
     &   +2.D0*rk(ipb(2,i))*rb(ipb(1,i))*ubc

         ri=rr(ipb(1,i))+rb(ipb(1,i))
         ci2=(cr2*rr(ipb(1,i))+cb2*rb(ipb(1,i)))/ri
         ti=(/0.D0,(ci2*c1d6*dt2,i=1,6),(ci2*c1d12*dt2,i=1,12)/) ! the first one is not important

         adat(1:3,ipb(3,i))=adat(1:3,ipb(3,i))
     &   -2.D0*((pcfr(niv(ipb(2,i)),ipb(1,i))
     &   +pcfb(niv(ipb(2,i)),ipb(1,i)))+(rk(ipb(2,i))*ubc-ti(ipb(2,i)))
     &   *ri)*vv(1:3,ipb(2,i))*rsdti2
        enddo

c!$OMP  PARALLEL DO PRIVATE(i)
c!$OMP& SHARED(npm,ipm,niv,fr,pcfr,fb,pcfb)
c        do i=1,npm                                ! multireflection boundary condition
c         fr(ipm(4,i),ipm(1,i))=pcfr(niv(ipm(4,i)),ipm(1,i)) ! bounce back
c         fb(ipm(4,i),ipm(1,i))=pcfb(niv(ipm(4,i)),ipm(1,i)) ! bounce back
c         q=ipmq(i)
c         q1=(1.D0-2.D0*q-2.D0*q**2)/((1.D0+q)**2)
c         q2=(q**2)/((1.D0+q)**2)
c         q3=1.D0/(4.D0*nu*((1.D0+q)**2))
c         f(ipm(1,i),ipm(4,i))=
c     &   pcf(ipm(1,i),niv(ipm(4,i)))+q1*pcf(ipm(2,i),niv(ipm(4,i)))
c     &   +q2*pcf(ipm(3,i),niv(ipm(4,i)))-q1*pcf(ipm(1,i),ipm(4,i))
c     &   -q2*pcf(ipm(2,i),ipm(4,i))
c     &   +q3*f2(ipm(4,i))
c        enddo
c!$OMP END PARALLEL DO

!$OMP  PARALLEL DO PRIVATE(i)
!$OMP& SHARED(nl,rr,fr,rb,fb,cf)
        do i=1,nl                          ! calculate color and density fields and interface
         rr(i)=fr(1,i)+fr(2,i)+fr(3,i)+fr(4,i)+fr(5,i)+fr(6,i)+fr(7,i)
     &        +fr(8,i)+fr(9,i)+fr(10,i)+fr(11,i)+fr(12,i)+fr(13,i)
     &        +fr(14,i)+fr(15,i)+fr(16,i)+fr(17,i)+fr(18,i)+fr(19,i)
         rb(i)=fb(1,i)+fb(2,i)+fb(3,i)+fb(4,i)+fb(5,i)+fb(6,i)+fb(7,i)
     &        +fb(8,i)+fb(9,i)+fb(10,i)+fb(11,i)+fb(12,i)+fb(13,i)
     &        +fb(14,i)+fb(15,i)+fb(16,i)+fb(17,i)+fb(18,i)+fb(19,i)
         cf(i)=(rr(i)-rb(i))/(rr(i)+rb(i)) ! color field
        enddo
!$OMP END PARALLEL DO

       enddo

c       CALL DATE_AND_TIME(date, time)
c       write(1313,*)'save start = ',time
       open(1,file='iteration')
       write(1,*)it1
       write(1,*)((fr(j,i),j=1,19),i=1,nl)
       write(1,*)((fb(j,i),j=1,19),i=1,nl)
       close(1)
       open(1,file='iteration2')
       write(1,*)it1
       write(1,*)((fr(j,i),j=1,19),i=1,nl)
       write(1,*)((fb(j,i),j=1,19),i=1,nl)
       close(1)
       call system('rm iteration')

       if(is==its) then
        is=0
        call save_results(ipcx,ipcy,ipcz,ind,nl,fr,fb,vv,mijk,ncx,ncy
     &       ,ncz,icor,sig,cr2,cb2,wet,it1,bfr,bfb,itw,rr,rb,cf
     &       ,rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti)         ! save results

       endif

c       CALL DATE_AND_TIME(date, time)
c       write(1313,*)'save end = ',time

c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'parallel region end = ',time
c      CALL DATE_AND_TIME(date, time)
c      write(1313,*)'check start = ',time

       call check_state(ipcx,ipcy,ipcz,ind,it1,fr,fb,nl,rr0,rb0,eps,
     &  ncx,ncy,ncz,istop,lsize,mijk,
     &  vir,vib,idir,t0,icor,sig,vv,cr2,
     &  cb2,wet,bfr,bfb,itw,rr,rb,cf,permro,permbo,
     &  rdat,vdat,adat,icors,ns,mijks,rsi,dt,dti)  ! check program state

       if(istop==1) then                                              ! check for quit
        return
       endif
c       CALL DATE_AND_TIME(date, time)
c       write(1313,*)'check end = ',time

      enddo

      return
      end


