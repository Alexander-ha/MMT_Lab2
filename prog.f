      program riters
c-----------------------------------------------------------------------
c test program for iters -- the basic iterative solvers
c-----------------------------------------------------------------------
      implicit none
      integer nmax, nzmax, maxits,lwk
      parameter (nmax=5000,nzmax=100000,maxits=60,lwk=nmax*40)
      integer ia(nmax),ja(nzmax),jau(nzmax),ju(nzmax),iw(nmax*3)
      integer ipar(16),nx,ny,nz,i,lfil,nwk,nrow,ierr,j,n
      real*8  a(nzmax),x(nmax),y(nmax),rhs(nmax),au(nzmax),wk(nmax*40)
      real*8  xran(nmax), fpar(16), al(nmax)
      real*8  gammax,gammay,alpha,tol
      external gen57pt,cg,bcg,dbcg,bcgstab,tfqmr,gmres,fgmres,dqgmres
      external cgnr, fom, runrc, ilut
      common /func/ gammax, gammay, alpha
c-----------------------------------------------------------------------  
c     set the parameters for the iterative solvers
c-----------------------------------------------------------------------  
      ipar(2) = 2       ! Use preconditioning
      ipar(3) = 1       ! Verbose output
      ipar(4) = lwk     ! Workspace size
      ipar(5) = 100     ! Max iterations
      ipar(6) = maxits  
      fpar(1) = 1.0D-10 ! Relative tolerance
      fpar(2) = 1.0D-20 ! Absolute tolerance
c--------------------------------------------------------------
c Read matrix and RHS from file
c--------------------------------------------------------------
      Open(10,file='CSRsystem', status='OLD',ERR=1000)
      Read(10,*,ERR=1001) n
      If(n.gt.nmax) Then
            Write(*,*) 'Increase maxn to', n
            Stop 911
      End if
      nrow = n
      Read(10,*,ERR=1001) (ia(j), j=1,n+1)
      nz = ia(n+1)-1
      If(nz.gt.nzmax) Then
        Write(*,*) 'Increase maxnz to', nz
        Stop 911
      End if
      Read(10,*,ERR=1001) (ja(j), j=1,nz)
      Read(10,*,ERR=1001) (a(j), j=1,nz)
      Read(10,*,ERR=1001) (y(j), j=1,n)
      Close(10)
      print *, 'n = ', n
      print *, 'ia = ', (ia(j), j=1,n+1)
      print *, 'ja = ', (ja(j), j=1,nz)
      print *, 'a = ', (a(j), j=1,nz)
      print *, 'rhs = ', (y(j), j=1,n)

c--------------------------------------------------------------
c Preconditioning with ILUT
c--------------------------------------------------------------
      lfil = 5          ! Fill-in parameter
      tol = 1.0D-3      ! Threshold
      nwk = nzmax
      call ilut(nrow, a, ja, ia, lfil, tol, au, jau, ju, nwk,
     *     wk, iw, ierr)
      If (ierr .ne. 0) Then
        Write(*, *) 'ILUT failed with error code', ierr
        Stop 911
      End if

c--------------------------------------------------------------
c Set initial guess and solve
c--------------------------------------------------------------
      do i = 1, n
         x(i) = 0.0D0   ! Initial guess
         xran(i) = 0.0D0
      end do

      print *, '	*** GMRES ***'
      call runrc(nrow,y,x,ipar,fpar,wk,xran,a,ja,ia,au,jau,ju,gmres)
      print *, 'Solution x = ', (x(j), j=1,n)
      open(unit=20, file='solution.txt', status='replace')
      do i = 1, n
         write(20, '(F20.15)') x(i)  ! Запись каждого элемента x(i) в файл
      end do
      close(20)
      print *, 'Solution saved to solution.txt'

      stop
 1000 Write(*,'(A)') 'Cannot open file CSRsystem'
      Stop 911
 1001 Write(*,'(A)') 'Corrupted data in CSRsystem'
      Stop 911
      end