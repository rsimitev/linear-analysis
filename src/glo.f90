!***********************************************************************
! Program to calc. lin. onset of conv. in rotating spherical shell.
!***********************************************************************
! Parameters:
! Rt=RAYLEIGH NUMBER, TA= TAYLOR NUMBER, Pt= PRANTEL NUMBER,
! ETA=RATIO OF RADII, Truncation= TRUNCATION, M0=WAVE NUMBER,
! Le = Lewis number,  CriticalRt=Rayleigh number due to concentration
! Symmetry= SYMMETRIE PARAMETER, Symmetry=0 : UNDEFINED SYMMETRIE,
! Symmetry=2 : EQUATORIAL SYMMETRIE, Symmetry=1 : EQUATORIAL ANTISYMMETRIE.
! DRIFT C IS DEFINED LIKE (PHI+C*T).
! Rev. 2.2: Drift is now def. as (phi-c*t).
!
! LCALC=1 : Eigenvalues are determined for const. parameters
! LCALC=2 : Onset determined for constant wavenumber M
!           (by searching root of grothrate in R, using pegasus.f).
! LCALC=3 : Onset determined by variing Rayleighnumber R and
!           wavenumber M.
! LCALC=4 : Eigenvector determined for one set of parameters
!           at onset
!
! LO.F calculates R (crit. Rayleighn.) and Omega (and M) in the
! range TAU=LowerLimit to TAU=UpperLimit.
! It only calculates the mode with minimal value of R.
!
! Start:    glo inputfilename outputfilename
!
#include "errorcodes.h"
#include "version.h"
program linearOnset
   use parameters
   use growthRateMod
   use glo_constants
   use io
   implicit none
   character*60 infile,outfile
   integer, parameter:: unitOut=16

!---------------------------------------------------------
!  arg #1 - filename or usage ?
   call getarg(1,infile)
   if (infile.eq.' ') then
      print*, 'Usage : '
      print*, 'glo <in file> <out file>'
      stop
   endif
   if (infile.eq.'-h') then
      print*, 'Usage : '
      print*, 'glo <in file> <out file>'
      stop
   endif

   call getarg(2,outfile)
   print*,  trim(infile),' - ',trim(outfile)

   call init(trim(infile),trim(outfile))

   select case(LCALC)
      !> Varies the thermal Rayleigh number and computes the growth rate for
      !! other parameters fixed.
      case(-1)
         call writeOutputHeader(unitOut)
         call fixedParGrowthRate()
      !> Computes the critical Thermal Rayleigh number for the onset of
      !! convections for all other parameters fixed.
      case(0)
         call writeOutputHeader(unitOut)
         call fixedParCriticalRa()
      !> Writes the (complex) eigenvalues of the problem for fixed parameters.
      !! The real part of the eigenvalues is the frequency of oscillation of the
      !! mode. The imaginary part is the symmetric of the growth rate.
      !! Modes are sorted from heighest to lowest growth rate.
      case(1)
         call writeOutputHeader(unitOut)
         call fixedParEigenValues()
      !> Computes the critical thermal Rayleigh number as a function of tau
      !! for all other parameters fixed.
      case(2)
         LowerLimit = tau
         call writeOutputHeader(unitOut)
         call varyTauCriticalRt(LowerLimit, UpperLimit)
      !> Computes the lowest critical thermal Rayleigh number of all m's
      !! as a function of tau for all other parameters fixed.
      case(3)
         LowerLimit = tau
         call writeOutputHeader(unitOut)
         call varyTauCriticalState(LowerLimit, UpperLimit)
      !> Computes the eigen vector
      !! Corresponding to the critical value of Rt with all other parameters
      !! fixed.
      case(4)
         call fixedParCriticalEigenVector()
      !> Computes the critical thermal Rayleigh number for a range of
      !! azimuthal wave-numbers m.
      case(5)
         LowerLimit = m0
         call writeOutputHeader(unitOut)
         call varyMCriticalRt(int(LowerLimit), int(UpperLimit))
      !> Varies the Lewis number and computes the critical
      !! thermal Rayleigh number for fixed other parameters.
      !! This subroutine changes the module variable "Le" during execution and does
      !! not restore it at the end.
      case(6)
         LowerLimit = Le
         call writeOutputHeader(unitOut)
         call varyLeCriticalRt(LowerLimit, UpperLimit)
      case(7) ! Loops through the m's to find the critical Par and m_c.
         if(trim(VariablePar)=='m') then
            Write(*,*) 'm is already varied in this computation.'
            Write(*,*) 'Chose one of Rt, Rc, tau, Pt, Le or eta'
            stop ERR_UNUSABLE_VARIABLE_PAR
         endif
         LowerLimit = m0
         call writeOutputHeader(unitOut)
         call fixedParCriticalParAndM0_v2()
      case(8) ! Loops through the m's to find the critical Rt=Rc and m_c.
         VariablePar = 'Ra'
         call setVariableParam(VariablePar)
         LowerLimit = m0
         call writeOutputHeader(unitOut)
         call CriticalRtSameAsRc()
      case default
         Write(*,*) 'Unknown computation type:', LCALC
   end select
   close(unitOut)
contains

   !**********************************************************************
   !> Initialises things.
   SUBROUTINE init(inputfile,outputfile)
      implicit none
      CHARACTER(len=*) inputfile,outputfile

      ! ----Default values:
      call setDefaults()
      ! ----INPUT:
      call readConfigFileNew(inputfile)

      ! ---- doesn't work for M=0 !!!!!!
      IF(M0.LT.1) THEN
        write(*,*) 'The code does not work for M0<1. ', M0, ' --> 1'
        M0 = 1
      ENDIF

      call setVariableParam(VariablePar)
      select case (VariablePar)
         case('Ra','aa')
            call GrowthRateInitAlpha(Ra, alpha, Pt, Le, tau, eta, m0, Symmetry, Truncation)
         case default
            call GrowthRateInit(Rt, Rc, Pt, Le, tau, eta, m0, Symmetry, Truncation)
      end select

      ! ----OUTPUT:
      OPEN(unitOut,FILE=outputfile,STATUS='UNKNOWN')
   END subroutine

   !**********************************************************************
   !> Writes the (complex) eigenvalues of the problem for fixed parameters.
   !! The real part of the eigenvalues is the frequency of oscillation of the
   !! mode. The imaginary part is the symmetric of the growth rate.
   !! Modes are sorted from heighest to lowest growth rate.
   subroutine fixedParEigenValues()
      implicit none
      double complex, allocatable:: ZEW(:)
      integer:: i, Nmodes
      Nmodes = getEigenProblemSize()
      allocate(ZEW(Nmodes))
      call computeGrowthRateModes(.true., zew)
      write(*,*) 'n     Frequ.(exp(+iwt))   -Grothrate  '
      write(unitOut,*) 'n     Frequ.(exp(+iwt))   -Grothrate  '
      do i=1, Nmodes
         WRITE(*,'(I4,2D16.6)') I,ZEW(I)
         WRITE(unitOut,'(I4,2D16.6)') I,ZEW(I)
      enddo
   end subroutine

   !**********************************************************************
   !> Varies the specified parameter and computes the growth rate for
   !! other parameters fixed. The step size is taken to be the order of
   !! magnitude of the value of the parameter (for example, if we are steping in
   !! Rt and Rt is 5*10^3, then the step size is 10^3). The step size is never
   !! smaller than \a StepSize.
   !!
   !! The output is written to file as "par, GR, W"
   subroutine fixedParGrowthRate()
      implicit none
      INTEGER:: aux
      double complex:: MaxEval
      double precision:: factor, par
      double precision:: dPar

      call saveParameterValue(par)
      if (par.gt.UpperLimit) then
         factor = -1.0d0
      else
         factor = 1.0d0
      endif
      do while(abs(par-UpperLimit) > abs(0.01*UpperLimit))
         aux  = int(log10(abs(par)))
         dPar = factor*10.0d0**(aux-1)/2.0d0
         if (abs(dPar) < abs(StepSize).or.par==0.0d0) dPar = factor*abs(StepSize)
         par  = par + dPar
         MaxEval = MaxGrowthRateCmplx(par)
         WRITE(*,*) par, dimag(MaxEval), dble(MaxEval)
         Write(unitOut, *) par, dimag(MaxEval), dble(MaxEval)
      enddo

      WRITE(*,*) '# R=',Rt,' TAU=',TAU,' P=',Pt,' M0=',M0,' eta=',ETA
      WRITE(*,*) '# Most unstable growth rate', dble(MaxEval)
      WRITE(*,*) '# If growth rate < 0 then above onset'
   end subroutine

   !**********************************************************************
   !> Computes the critical Thermal Rayleigh number for the onset of
   !! convections when all other parameters are considered fixed.
   subroutine fixedParCriticalRa()
      implicit none
      double Complex:: frequency
      double precision:: CriticalRt, Omega, GroR
      integer:: info
      call minimizer(MaxGrowthRate,Rt/10, Rt*10,RELE,ABSE,NSMAX,CriticalRt, info)
      frequency = MaxGrowthRateCmplx(CriticalRt)
      GROR  = dimag(frequency)
      OMEGA = -dble(frequency)
      Write(unitOut,*) CriticalRt, Omega, GroR
      WRITE(*,*) 'TAU=',TAU,' Pt=',Pt,' M0=',M0,' eta=',ETA
      WRITE(*,*) 'Lewis=',Le,' Rc=',Rc
      WRITE(*,*) 'R_crit=',CriticalRt, '  (growth rate =',GROR,')'
   end subroutine

   !**********************************************************************
   !> For the specified parameter, finds the global critical value
   !! for all other parameters fixed. At the end, m0 is teh critical m
   !! and the critical value of VariablePar is updated in the growth rate 
   !! module.
   subroutine fixedParCriticalParAndM0_v2()
      implicit none
      double precision:: aux
      double precision:: ParMin, ParMax
      double precision:: CriticalPar, origParVal
      INTEGER:: CriticalM
      integer:: info, i

      info=0
      select case (trim(VariablePar))
         case('Rt','Rc','Ra')
            CriticalPar = 1.0d100
         case default
            CriticalPar = -1.0d100
      end select
      call saveParameterValue(origParVal)
      Write(*,*) '#----------------------------------------'
      WRITE(*,*) '# eta = ',ETA
      WRITE(*,*) '# m0  = ',M0
      WRITE(*,*) '# tau = ',TAU
      WRITE(*,*) '# Pt  = ',Pt
      WRITE(*,*) '# Le  = ',Le
      WRITE(*,*) '# Rc  = ',Rc
      WRITE(*,*) '# Rt  = ',Rt
      Write(*,*) '# Truncation = ', Truncation
      Write(*,*) '# Finding critical ', trim(VariablePar), ' arround ', origParVal
      Write(*,*) '#----------------------------------------'
      Write(*,*) '#       ', trim(VariablePar)//'_c', '      m'
      !
      Write(unitOut,*) '# Finding critical ', trim(VariablePar), ' arround ', origParVal
      DO m0=nint(LowerLimit), nint(UpperLimit), nint(StepSize)
         call GrowthRateUpdatePar(m=m0)
         ! Increase the interval, in case we did not find anything.
         do i=0, 10
            info=0
            ParMin = origParVal - 2.0**(i-2)*dabs(origParVal)
            ParMax = origParVal + 2.0**(i-2)*dabs(origParVal)

            ! Only Rt, Rc or alpha can have negative values.
            if (trim(VariablePar).ne.'Rt'.or. &
                trim(VariablePar).ne.'Rc'.or. &
                trim(VariablePar).ne.'aa') then
                  if (ParMin.lt.0.0d0) ParMin = 0.0d0
            endif
            if (i.gt.9) then
               Write(*,*) i,': Damn! 9 iterations and I could find nothing?'
               ParMin = -1.0d20
               ParMax = 1.0d20
            endif

            call minimizer(MaxGrowthRate, ParMin, ParMax, RELE ,ABSE, NSMAX, aux, info)
            if (info.eq.0) exit
         enddo
         if(info.NE.0) then
            Write(*,*) 'Failed to find roots: error:', info
            info=0
            cycle 
         endif
         ! Critical values are above the line for Rc and Rt
         ! But below the line for the other parameters
         select case (trim(VariablePar))
            case('Rt','Rc','Ra')
               if (aux < CriticalPar) then
                  CriticalPar = aux
                  CriticalM  = m0
               endif
            case default
               if (aux > CriticalPar) then
                  CriticalPar = aux
                  CriticalM  = m0
               endif
         end select
         write( unitOut,'(1X,1P,E17.6,I4)') aux, M0
         write( *,'(1X,1P,E17.6,I4)') aux, M0
      enddo
      call setParameterValue(CriticalPar)
      call GrowthRateUpdatePar(m=CriticalM)
      m0 = CriticalM
      write( unitOut,'(">",1P,E17.6,I4)')  CriticalPar, CriticalM
      write( *,'(">",1P,E17.6,I4)')    CriticalPar, CriticalM
   end subroutine

   !**********************************************************************
   !> Computes the lowest critical thermal Rayleigh number of all m's
   !! for all other parameters fixed.
   subroutine fixedParCriticalRaAndM0(CriticalRt)
      implicit none
      double precision, intent(out):: CriticalRt
      integer, parameter::nm0=3
      double precision:: Omega
      double precision:: RACI(nm0),OMI(nm0),GRORi(nm0)
      double precision:: RtMin, RtMax
      double Complex:: frequency
      INTEGER:: M0I(nm0),LLI(nm0)
      INTEGER, save:: NTRYCOUNT=0
      integer:: first_m0, i, ii
      integer:: info, idx

      info=0
      CriticalRt = Rt
      do i=0, nm0/2
         first_m0   = m0 - i
         if (first_m0==1) exit
      enddo
!     Start a search around the previous m0
      do i=1, nm0
        M0I(i)   = first_m0+i-1
      enddo
      DO II=1, nm0
         M0   = M0I(II)
         call GrowthRateUpdatePar(m=m0)
         ! Increase the interval, in case we did not find anything.
         do i=1, 3
            RtMin = Rt/(2.0d0**dble(i))
            RtMax = Rt*(2.0d0**dble(i))
            call minimizer(MaxGrowthRate, RtMin, RtMax, RELE ,ABSE, NSMAX, CriticalRt, info)
            if (info.NE.2) exit
         enddo
         if(info.NE.0) then
            Write(*,*) 'Failed to find roots: error:', info
            stop 5
         endif
         ! Compute the grouth rate for each case so we can output it for
         ! debug purposes.
         frequency = MaxGrowthRateCmplx(CriticalRt)
         GRORi(ii) = dimag(frequency)
         OMI(II) = -dble(frequency)
         RACI(II)= CriticalRt
         LLI(II) = info
         write( *,'(1X,1P,4E17.6,I4,A3,2E17.6)') TAU, CriticalRt, OMI(II), GRORi(ii), M0,' | ', CriticalRt*(1/(1-eta))**4*(2/TAU),(OMI(II)*2.0/TAU)
      enddo

      ! Let's not allow growth rates that are too high
      if(any(lli.eq.0)) then
         where(lli.NE.0) RACI = 1.0d100
         idx = minloc(RACI,1)
      else
         idx = 0
      endif

      IF( idx.GT.0 ) THEN
         CriticalRt   = RACI(idx)
         OMEGA = OMI(idx)
         M0    = M0I(idx)
         write( unitOut,'(1P,3E17.6,I4)') TAU, CriticalRt, OMEGA, M0
         write( *,'(">",1P,3E17.6,I4,A3,2E17.6)') TAU,CriticalRt,OMEGA, M0,' | ', CriticalRt*(1/(1-eta))**4*(2/TAU),(OMEGA*2.0/TAU)
         write(*,*)
         NTRYCOUNT = 0
      ELSE IF(NTRYCOUNT.GE.3) THEN
         WRITE(unitOut,*) 'NO CRITICAL RAYLEIGH NUMBER FOUND.'
         STOP NO_RA_FOUND
      ELSE
         write(*,*) 'NO CRIT. RAYLEIGH NUMBER FOUND. Trying again.'
         NTRYCOUNT = NTRYCOUNT + 1
      ENDIF
   end subroutine

   !**********************************************************************
   !> Computes and Writes out the eigen vector (equatorial render)
   !! Corresponding to the critical value of Rt with all other parameters
   !! fixed.
   subroutine fixedParCriticalEigenVector()
      implicit none
      double precision:: GroR, Omega
      complex(8), allocatable:: ZEVEC(:), zew(:), ZEVAL(:,:)
      integer:: i, ni, li, lti, lpi, Nmodes, ld
      integer:: LMAX, NIMAX, LMIN, eqdim

      ! find the zero grothrate:
      LowerLimit = m0
      call fixedParCriticalParAndM0_v2()
      close(unitOut)
      OPEN(unitOut,FILE=outfile,STATUS='UNKNOWN')
      call setLminAndLD(Symmetry, m0, LMIN, LD)
      Nmodes = getEigenProblemSize()
      eqdim=nModes/4
      ! Allocate space for the eigen modes and vectors
      allocate( ZEVEC(Nmodes), zew(Nmodes), ZEVAL(Nmodes,Nmodes))
      ! Recoompute critical state modes and eigenvectors
      call computeGrowthRateModes(sort=.TRUE., zew=zew, zeval=zeval)
      ! Most unstable mode will be the first
      GROR  = -DIMAG(zew(1))
      Omega = dble(zew(1))
      zevec(:) = zeval(:,1)

      ! print eigenvector
      WRITE(unitOut,*) '# Linear onset coefficients'
      WRITE(unitOut,'(3I5,2D16.8," M0, TRUNC, Symmetry, GR, DRIFT")')  M0, Truncation, Symmetry, GROR, Omega
      WRITE(unitOut, '(6D14.6," Ta, Rt, Rc, Pt, Pc, eta")') tau, Rt, Rc, Pt, Le/Pt, ETA

      LMAX=2*Truncation+M0-1
      ! poloidal flow:
      I=0
      DO LI=LMIN,LMAX,LD
         LPI = LI
         NIMAX=INT( DBLE(2*Truncation+1-LI+M0)/2 )
         DO NI=1,NIMAX
            WRITE(unitOut,'(1X,A1,3I3,2D16.8)') 'V', LPI, M0, NI, DREAL(ZEVEC(I+0*eqdim+1)), DIMAG(ZEVEC(I+0*eqdim+1))
            I=I+1
         enddo
      enddo
      ! toroidal  flow:
      I=0
      DO LI=LMIN,LMAX,LD
         IF( Symmetry.EQ.2 ) THEN
         LTI=LI+1
         ELSEIF( Symmetry.EQ.1 ) THEN
         LTI=LI-1
         ELSEIF( Symmetry.EQ.0 ) THEN
         LTI=LI
         ENDIF
         NIMAX=INT( DBLE(2*Truncation+1-LI+M0)/2 )
         DO NI=1,NIMAX
            WRITE(unitOut,'(1X,A1,3I3,2D16.8)') 'W', LTI, M0, NI, DREAL(ZEVEC(I+1*eqdim+1)), DIMAG(ZEVEC(I+1*eqdim+1))
            I=I+1
         enddo
      enddo
      ! temperature
      I=0
      DO LI=LMIN,LMAX,LD
         NIMAX=INT( DBLE(2*Truncation+1-LI+M0)/2 )
         DO NI=1,NIMAX
            WRITE(unitOut,'(1X,A1,3I3,2D16.8)') 'T', LI, M0, NI, DBLE(ZEVEC(I+2*eqdim+1)), DIMAG(ZEVEC(I+2*eqdim+1))
            I=I+1
         enddo
      enddo
      ! composition
      I=0
      DO LI=LMIN,LMAX,LD
         NIMAX=INT( DBLE(2*Truncation+1-LI+M0)/2 )
         DO NI=1,NIMAX
            WRITE(unitOut,'(1X,A1,3I3,2D16.8)') 'G', LI, M0, NI, DREAL(ZEVEC(I+3*eqdim+1)), DIMAG(ZEVEC(I+3*eqdim+1))
            I=I+1
         enddo
      enddo
   end subroutine

   !**********************************************************************
   !> Computes the critical thermal Rayleigh number as a function of tau
   !! for all other parameters fixed.
   !! This subroutine changes the module variables tau and Rt.
   subroutine varyTauCriticalRt(tauMin, tauMax)
      implicit none
      double precision, intent(in):: tauMin, tauMax
      integer:: NTRYCOUNT, info
      double complex:: frequency
      double precision:: CriticalRt, GroR, RtOld
      double precision:: Tau0, Tau1, omega, RtMin, RtMax

      NTRYCOUNT = 0
      Rtold = Rt
      TAU1 = tauMin
      tau = tauMin
      tauLoop:do
         ! searching for zero grothrate by varying Rt: ----------------------
         RtMin = Rt/5.0
         RtMax = Rt*5
         RtOld = Rt
         call GrowthRateUpdatePar(tau=tau)
         call minimizer(MaxGrowthRate, RtMin, RtMax, RELE, ABSE, 50, CriticalRt, info)
         frequency = MaxGrowthRateCmplx(CriticalRt)
         GROR  = dimag(frequency)
         OMEGA = -dble(frequency)
         IF(info.EQ.0) THEN
            WRITE(unitOut,'(1P,3E17.6,I4)') TAU,CriticalRt,OMEGA,M0
            WRITE( *,'(1P,3E17.6,I4)') TAU,CriticalRt,OMEGA,M0
            NTRYCOUNT = 0
         ELSE
            write(*,*) '# NO CRIT. RAYLEIGH NUMBER FOUND. Trying again.'
            NTRYCOUNT = NTRYCOUNT + 1
         ENDIF
!--      increment TAU:
         TAU0 = TAU1
         TAU1 = TAU
         IF(NTRYCOUNT==0) THEN
            IF( DABS(StepSize) .LT. TAU*0.1D0 ) THEN
               TAU = TAU1 + StepSize
            ELSE
               TAU = TAU1 + 10.0d0**(int(log10(abs(tau1)))-1)*sign(1.0d0,StepSize)
            ENDIF
!--         interpolate new startingvalue for Rt:
!           Assume CriticalRt grows with tau**(4/3)
            Rt = CriticalRt + (4.0/3.0)*Tau1**(1.0/3.0)*(TAU-TAU1)
            RtOld = CriticalRt
         ELSE
            Rt = CriticalRt
         ENDIF

         if (NTRYCOUNT==3) exit
         ! end value of TAU reached?
         if(tauMax.GT.tauMin) then
            if (TAU.GT.tauMax) exit
         else
            if (TAU.LT.tauMin) exit
         endif
      enddo tauLoop
   end subroutine

   !**********************************************************************
   !> Computes the lowest critical thermal Rayleigh number of all m's
   !! as a function of tau for all other parameters fixed.
   !! This subroutine changes the module variables tau and Rt.
   subroutine varyTauCriticalState(tauMin, tauMax)
      implicit none
      double precision, intent(in):: tauMin, tauMax
      double precision:: CriticalRt, RtOld
      double precision:: Tau0, Tau1
      Rtold = Rt
      TAU1  = tauMin
      tau   = tauMin
      tauLoop:do
         !--------searching for zero grothrate by varying Rt and M0: ---------------
         call GrowthRateUpdatePar(tau=tau, Rt=Rt)
         call fixedParCriticalRaAndM0(CriticalRt)
!--      increment TAU:
         TAU0 = TAU1
         TAU1 = TAU
         IF( DABS(StepSize) .LT. DABS(TAU*0.1D0) ) THEN
            TAU = TAU1 + StepSize
         ELSE
            TAU = TAU1 + 10.0d0**(int(log10(abs(tau1)))-1)*StepSize/dabs(StepSize)
         ENDIF
!--      interpolate new estimate for Rt_c:
         IF(dabs(TAU1-TAU0).le.1.0d-10) THEN
!          Assume Rac grows with Ta**(4/3)
           Rt = CriticalRt + (4.0/3.0)*Tau1**(1.0/3.0)*(TAU-TAU1)
         ELSE
           Rt = 2.0D0*CriticalRt - RtOld
         ENDIF
         RtOld = CriticalRt

         ! end value of TAU reached?
         if(tauMax.GT.tauMin) then
            if (TAU.GT.tauMax) exit
         else
            if (TAU.LT.tauMax) exit
         endif
      enddo tauLoop
   end subroutine

   !**********************************************************************
   !> Computes the critical thermal Rayleigh number for a range of
   !! azimuthal wave-numbers m.
   subroutine varyMCriticalRt(mMin, mMax)
      implicit none
      integer, intent(in):: mMin, mMax
      double precision:: CriticalRt, MinCriticalRt
      integer:: info, MforMinCriticalRt
      CriticalRt=Rt
      MinCriticalRt=100.d10
      MforMinCriticalRt=2000
      do M0=mMin, mMax, INT(StepSize)
         call GrowthRateUpdatePar(m=m0)
         call minimizer(MaxGrowthRate,Rt/10, Rt*10,RELE,ABSE,NSMAX,CriticalRt, info)
         if(info.NE.0) then
            Write(*,*) 'Failed to find roots: error:', info
            stop 5
         endif
         WRITE(unitOut,*) M0, CriticalRt
         WRITE(*,*) M0,CriticalRt
         if (CriticalRt < MinCriticalRt) then
            MinCriticalRt     = CriticalRt
            MforMinCriticalRt = M0
         endif
      enddo
      write( unitOut,'(">",1P,E17.6,I4)')  MinCriticalRt, MforMinCriticalRt
      write( *,'(">",1P,E17.6,I4)')  MinCriticalRt, MforMinCriticalRt
   end subroutine

   !**********************************************************************
   !> Varies the Lewis number and computes the critical
   !! thermal Rayleigh number for fixed other parameters.
   !! This subroutine changes the module variable "Le" during execution
   !! and does not restore it at the end.
   subroutine varyLeCriticalRt(LeMin, LeMax)
      implicit none
      double precision, intent(in):: LeMin, LeMax
      double precision:: LeOld, GroR
      double precision:: CriticalRt, RtMin, RtMax, dRt
      integer:: niter, i, info, counter
      niter = int((LeMax-LeMin)/StepSize)
      dRt = Rt
      do i=0, niter
         Le  = LeOld + i*StepSize
         RtMin = Rt - dRt
         RtMax = Rt + dRt
         counter = 0
         do
            call GrowthRateUpdatePar(Le=Le)
            call minimizer(MaxGrowthRate,RtMin, RtMax,RELE,ABSE,NSMAX,CriticalRt, info)
            if (info==0 .or. counter.gt.20) exit
            counter = counter + 1
            RtMin = RtMin - dRt
            RtMax = RtMax + dRt
            Write(*,*) 'Minimization failed. Trying with a larger interval [', RtMin, RtMax, ']'
         enddo
         Rt   = CriticalRt
         if (abs(Rt).gt.1.0d100) then
            Write(*,*) "Rt=",Rt
            Write(*,*) "This is way too much. Bayling out!"
            exit
         endif

         dRt  = CriticalRt/10.0d0
         GROR = MaxGrowthRate(CriticalRt)
         WRITE(*,*) Le, CriticalRt, GROR
         WRITE(unitOut,'(3D16.8)') Le, CriticalRt, GROR
      enddo
   end subroutine

   !**********************************************************************
   !> Computes the global critical thermal Rayleigh number that equals the
   !! compositional Rayleigh number for fixed other parameters.
   subroutine CriticalRtSameAsRc()
      implicit none
      ! Compute the Critical Ra for alpha=pi/4
      call GrowthRateUpdateParAlpha(alpha=dpi/4.0)
      call fixedParCriticalParAndM0_v2()
      call saveParameterValue(Ra)
      WRITE(*,*) ">>", Rt, Rc, m0
      WRITE(unitOut,'(A,2D16.8,I4)') ">>", Rt, Rc, m0
   end subroutine
end program
! vim: tabstop=3:softtabstop=3:shiftwidth=3:expandtab
