module parameters
  implicit none
  ! Adimensional parameters
  double precision:: TAU,Rt,Pt,C,Le,Rc,eta
  ! Alternative parametrisation for the Rayleigh numbers
  double precision:: Ra, alpha
  ! Dimensions
  integer::Truncation,M0,Symmetry, NSMAX, LCALC
  double precision:: LowerLimit,UpperLimit,StepSize,ABSE,RELE
  character(len=3):: VariablePar
contains
   subroutine setDefaults()
      implicit none
      Symmetry = 2
      LCALC = 2
      Rt   = 4.D3
      Rc   = 0.D0
      Ra   = Rt
      alpha = 0.0d0
      TAU  = 100.0D0
      LowerLimit  = TAU
      UpperLimit  = 10*LowerLimit
      Pt   = 1.D-1
      Le   = 1.D00
      ETA  = 0.4D0
      Truncation = 3
      M0   = 6
      ABSE = 1.0d-6
      RELE = 1.0d-6
      NSMAX = 100
      VariablePar='Rt'
   end subroutine
end module parameters
! vim: tabstop=3:softtabstop=3:shiftwidth=3:expandtab
