C ======================================================================
C The program reads a system in CSR format, initialize ILU0 preconditioner,
C and solve the system by preconditioned BiCGstab method
C ======================================================================
      Program  mainBcgILU0
      implicit none

C Maximum size of matrix and the maximum number of non-zero entries
      Integer   maxn, maxnz 
      Parameter(maxn = 100000, maxnz = 1000000)

C Arrays for the matrix sparse row (CSR) format
      Integer  ia(maxn+1), ja(maxnz)
      Real*8    a(maxnz), f(maxn), u(maxn)

C Work arrays to keep ILU factors and 8  vectors 
      Integer   MaxWr, MaxWi
      Parameter(MaxWr = maxnz + 8*maxn, MaxWi = maxnz + 2*maxn+1)
      Real*8    rW(MaxWr)
      Integer   iW(MaxWi)

C BiCGStab data
      External  matvec, prevec0
      Integer   ITER, INFO, NUNIT
      Real*8    RESID

C ILU0 data
      Integer   ierr, ipaLU, ipjLU, ipjU, ipiw

C External routines from BLAS library
      Real*8    ddot
      External  ddot, dcopy    

C Local variables
      Integer   imatvec(1), iprevec(1), ipBCG
      Real*8    resinit
      Integer   n,i,j,nz

C ======================================================================
C  STAGE 1: read system in CSR format
C ======================================================================
      Open(10,file='CSRsystem',
     &        status='OLD',ERR=1000)
        Read(10,*,ERR=1001) n
        If(n.gt.maxn) Then
           Write(*,*) 'Increase maxn to', n
           Stop 911
        End if

        Read(10,*,ERR=1001) (ia(i), i=1,n+1)
        nz = ia(n+1)-1
        If(nz.gt.maxnz) then
           Write(*,*) 'Increase maxnz to', nz
           Stop 911
        End if

        Read(10,*,ERR=1001) (ja(j), j=1,nz)
        Read(10,*,ERR=1001) (a(j),  j=1,nz)
        Read(10,*,ERR=1001) (f(i),  i=1,n)
      Close(10)


C ======================================================================
C  STAGE 2: initialization of the preconditioner
C ======================================================================
      ipaLU = 1
      ipBCG = ipaLU+nz
      ipjU  = 1
      ipjLU = ipjU+n+1
      ipiw  = ipjLU+nz !work array of length n

      Call ilu0(n,a,ja,ia, rW(ipaLU),iW(ipjLU),iW(ipjU),iW(ipiw),ierr)

      If(ierr.ne.0) Then
         Write(*,'(A,I7)') 'initialization of ilu0 failed, ierr =', ierr
         Goto 1002
      End if
c Keep data in rW and iW up to rW(nz) and iW(nz+n+1) !


C ======================================================================
C  STAGE 3: set initial guess and compute initial residual
C ======================================================================
c  set initial guess to 0
      Call dcopy(n,0d0,0,u,1)

c  compute initial residual norm
      resinit = ddot(n,f,1,f,1)
      resinit = dsqrt(resinit)
      If(resinit.eq.0d0) Then
         Write(*,'(A)') 'rhs=0, nothing to solve!'
         Goto 1002
      End if

C ======================================================================
C  STAGE 4: iterative solution
C ======================================================================
      ITER = 1000             ! max number of iterations
      RESID = 1d-8 * resinit  ! threshold for \|RESID\|
      INFO  = 0               ! no troubles on input
      NUNIT = 6               ! output channel
      iprevec(1) = n          ! single entry required: system size 
      imatvec(1) = n          ! single entry required: system size 


      call slpbcgs(
     >     prevec0, iprevec, iW,rW,
     >     matvec,  imatvec, ia,ja,a,
     >     rW(ipBCG), n, 8,
     >     n, f, u,
     >     ITER, RESID,
     >     INFO, NUNIT)
      If(INFO.ne.0) Then
         Write(*,'(A)') 'BiCGStab failed'
         Goto 1002
      End if
      Open(unit=20, file='output.txt', status='replace', action='write')
      do 101 i=1,n
            Write(*,*) 'i=', i, ' u(i)=', u(i)
            Write(20, '(F12.6)') u(i)
 101  continue
      Stop
 1000 Continue
      Write(*,'(A)') 'Cannot open file CSRsystem'
      Stop 911
 1001 Continue
      Write(*,'(A)') 'Corrupted data in CSRsystem'
      Stop 911
 1002 Continue
      Stop 911

      End Program mainBcgILU0