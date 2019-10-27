  subroutine linmin_exchng(a,b,x,y,t,q,n)
!
!  The contents of a, c, t, and x are stored in b, d, q, and y!
!  This is a dedicated routine, it is called by linmin only.
!
  implicit none
  integer, parameter :: dp  = kind(1.0d0)
  integer, parameter :: i4  = selected_int_kind(5)
!
!  Passed variables
!
  integer(i4)    :: n
  real(dp)       :: a
  real(dp)       :: b
  real(dp)       :: t
  real(dp)       :: q
  real(dp)       :: x(*)
  real(dp)       :: y(*)
!
!  Local variables
!
  integer(i4)    :: i
!
  b = a
  q = t
  do i = 1,n
    y(i) = x(i)
  enddo
!
  return
  end
