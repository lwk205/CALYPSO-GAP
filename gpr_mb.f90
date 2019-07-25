! XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
! X  the module of gaussian process regression 
! X  for many-body interaction
! X  Qunchao Tong 2019.07.24 20:55
! X
! X
! XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
MODULE GPR_MB
use constants
use io
use math
use linearalgebra
use struct

CONTAINS
SUBROUTINE INI_GAP_MB(GAP, ACSF, nsparse, nobf)
type(GAP_type),intent(inout)           :: GAP
type(ACSF_type),intent(inout)          :: ACSF
integer,intent(in)                     :: nsparse, nobf

!local

call READ_ACSF('neural.in', ACSF)
GAP%nsparse = nsparse
GAP%dd = ACSF%NSF * 2     ! D_tot = D_topology + D_species
GAP%nglobalY = nobf

allocate(GAP%cmm(GAP%nsparse, GAP%nsparse))
allocate(GAP%cmo(GAP%nsparse, GAP%nglobalY, 1))
allocate(GAP%sparseX(GAP%nsparse, GAP%dd))
allocate(GAP%obe(GAP%nglobalY))
allocate(GAP%coeff(GAP%nsparse, 1))
allocate(GAP%lamda(GAP%nglobalY))
allocate(GAP%lamdaobe(GAP%nglobalY))

END SUBROUTINE INI_GAP_MB

SUBROUTINE CAR2ACSF(at, GAP, ACSF)

implicit real(DP) (a-h,o-z)

type(Structure),intent(inout)          :: at
type(GAP_type),intent(in)              :: GAP
type(ACSF_type),intent(in)             :: acsf

!local
REAL(DP),dimension(3)                  :: xyz, xyz_j, xyz_k

allocate(at%xx(GAP%dd, at%natoms))
allocate(at%dxdy(GAP%dd, at%natoms, at%natoms, 3))
allocate(at%strs(3, 3, GAP%dd, at%natoms))

nnn = ACSF%nsf
do ii = 1, nnn
print*, 'BBBBBBBBBBBBBBB'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
!G1 = SUM_j{exp(-alpha*rij**2)*fc(rij)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if (ACSF%sf(ii)%ntype.eq.1) then
        do i = 1, at%natoms
            do i_type = 1, nspecies
                do i_neighbor = 1, at%atom(i)%count(i_type)
                    rij = at%atom(i)%neighbor(i_type,i_neighbor,4)
                    xyz = at%atom(i)%neighbor(i_type,i_neighbor,1:3)
                    n = int(at%atom(i)%neighbor(i_type,i_neighbor,5))
                    cutoff = ACSF%sf(ii)%cutoff
                    alpha = ACSF%sf(ii)%alpha
                    weights = at%mlp_weights(n)
                    if (rij.gt.cutoff) cycle
                    deltaxj = -1.d0*(at%atom(i)%pos(1) - xyz(1))
                    deltayj = -1.d0*(at%atom(i)%pos(2) - xyz(2))
                    deltazj = -1.d0*(at%atom(i)%pos(3) - xyz(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    fcutij = 0.5d0 * (dcos(pi*rij/cutoff) + 1.d0)
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                    at%xx(ii,i) = at%xx(ii,i) + dexp(-1.d0*alpha*rij**2)*fcutij
                    at%xx(ii + nnn, i) = at%xx(ii + nnn, i) + dexp(-1.d0*alpha*rij**2)*fcutij * weights !!!!!!! 

                    !dxx/dx
                    temp1=-2.d0*alpha*rij*dexp(-1.d0*alpha*rij**2)*fcutij
                    temp2= dexp(-1.d0*alpha*rij**2)

                    at%dxdy(ii,i,i,1)=at%dxdy(ii,i,i,1)+(drijdxi*temp1 + temp2*dfcutijdxi)
                    at%dxdy(ii+nnn,i,i,1)=at%dxdy(ii+nnn,i,i,1) + &
                    (drijdxi*temp1+ temp2*dfcutijdxi) * weights
                
                    temp3=drijdxj*temp1 + temp2*dfcutijdxj
                    at%dxdy(ii,i,n,1)=at%dxdy(ii,i,n,1)+temp3
                
                    temp4=temp3*weights
                    at%dxdy(ii + nnn,i,n,1)=at%dxdy(ii + nnn,i,n,1)+temp4
                
                    at%strs(1,1,ii,i)=at%strs(1,1,ii,i)+deltaxj*temp3
                    at%strs(2,1,ii,i)=at%strs(2,1,ii,i)+deltayj*temp3
                    at%strs(3,1,ii,i)=at%strs(3,1,ii,i)+deltazj*temp3
                
                    at%strs(1,1,ii+nnn,i)=at%strs(1,1,ii+nnn,i)+deltaxj*temp4
                    at%strs(2,1,ii+nnn,i)=at%strs(2,1,ii+nnn,i)+deltayj*temp4
                    at%strs(3,1,ii+nnn,i)=at%strs(3,1,ii+nnn,i)+deltazj*temp4
                    !dxx/dy
                    at%dxdy(ii,i,i,2)=at%dxdy(ii,i,i,2)+(drijdyi*temp1+temp2*dfcutijdyi)
                    at%dxdy(ii+nnn,i,i,2)=at%dxdy(ii+nnn,i,i,2)+(drijdyi*temp1+temp2*dfcutijdyi)*weights
                    temp3= drijdyj*temp1 + temp2*dfcutijdyj
                    at%dxdy(ii,i,n,2)=at%dxdy(ii,i,n,2)+temp3
                    temp4=temp3 * weights
                    at%dxdy(ii + nnn,i,n,2)=at%dxdy(ii + nnn ,i,n,2)+temp4
                
                    at%strs(1,2,ii,i)=at%strs(1,2,ii,i)+deltaxj*temp3
                    at%strs(2,2,ii,i)=at%strs(2,2,ii,i)+deltayj*temp3
                    at%strs(3,2,ii,i)=at%strs(3,2,ii,i)+deltazj*temp3
                
                    at%strs(1,2,ii + nnn,i)=at%strs(1,2,ii + nnn,i)+deltaxj*temp4
                    at%strs(2,2,ii + nnn,i)=at%strs(2,2,ii + nnn,i)+deltayj*temp4
                    at%strs(3,2,ii + nnn,i)=at%strs(3,2,ii + nnn,i)+deltazj*temp4
                    !dxx/dz
                    at%dxdy(ii,i,i,3)=at%dxdy(ii,i,i,3)+&
                           (drijdzi*temp1&
                          + temp2*dfcutijdzi)
                    at%dxdy(ii + nnn,i,i,3)=at%dxdy(ii + nnn,i,i,3)+&
                           (drijdzi*temp1&
                          + temp2*dfcutijdzi)*weights
                    temp3=drijdzj*temp1 + temp2*dfcutijdzj
                    at%dxdy(ii,i,n,3)=at%dxdy(ii,i,n,3)+temp3
                    temp4=temp3*weights
                    at%dxdy(ii + nnn,i,n,3)=at%dxdy(ii + nnn,i,n,3)+temp4
                
                    at%strs(1,3,ii,i)=at%strs(1,3,ii,i)+deltaxj*temp3
                    at%strs(2,3,ii,i)=at%strs(2,3,ii,i)+deltayj*temp3
                    at%strs(3,3,ii,i)=at%strs(3,3,ii,i)+deltazj*temp3
                
                    at%strs(1,3,ii + nnn,i)=at%strs(1,3,ii + nnn,i)+deltaxj*temp4
                    at%strs(2,3,ii + nnn,i)=at%strs(2,3,ii + nnn,i)+deltayj*temp4
                    at%strs(3,3,ii + nnn,i)=at%strs(3,3,ii + nnn,i)+deltazj*temp4
                enddo ! i_neighbor
            enddo ! i_type
        enddo ! i
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
! lamda = 1
! eta = 1
! G2 = SUM_jk{(1+lamda*costheta_ijk)^eta*
! exp(-alpha*(rij**2+rik**2+rjk**2))*fc(rij)*fc(rik)*fc(rjk)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    elseif (ACSF%sf(ii)%ntype.eq.2) then
        cutoff = ACSF%sf(ii)%cutoff
        alpha = ACSF%sf(ii)%alpha
        print*, 'cutoff',cutoff,'alpha',alpha
        do i = 1, at%natoms
            lllll = 0
            do j_type = 1, nspecies
                do j_neighbor = 1, at%atom(i)%count(j_type)
                    rij = at%atom(i)%neighbor(j_type,j_neighbor,4)
                    xyz_j = at%atom(i)%neighbor(j_type,j_neighbor,1:3)
                    n = int(at%atom(i)%neighbor(j_type,j_neighbor,5))
                    weights_j = at%mlp_weights(n)
                    if (rij.gt.cutoff) cycle
                    !print*,  xyz_j,'j'
                    deltaxj = -1.d0*(at%atom(i)%pos(1) - xyz_j(1))
                    deltayj = -1.d0*(at%atom(i)%pos(2) - xyz_j(2))
                    deltazj = -1.d0*(at%atom(i)%pos(3) - xyz_j(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    drijdxk = 0.d0
                    drijdyk = 0.d0
                    drijdzk = 0.d0
                    fcutij=0.5d0*(dcos(pi*rij/cutoff)+1.d0)
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                    dfcutijdxk=0.0d0
                    dfcutijdyk=0.0d0
                    dfcutijdzk=0.0d0
                    do k_type = 1, nspecies
                        do k_neighbor = 1, at%atom(i)%count(k_type)
                            if ((k_type <= j_type) .and. (k_neighbor <= j_neighbor)) cycle
                            rik = at%atom(i)%neighbor(k_type,k_neighbor,4)
                            if (rik.gt.cutoff) cycle
                            lllll = lllll + 1
                            xyz_k = at%atom(i)%neighbor(k_type,k_neighbor,1:3)
                    !        print*, xyz_k,'k'
                            m = int(at%atom(i)%neighbor(k_type,k_neighbor,5))
                            weights_k = at%mlp_weights(m)

                            deltaxk = -1.d0*(at%atom(i)%pos(1) - xyz_k(1))
                            deltayk = -1.d0*(at%atom(i)%pos(2) - xyz_k(2))
                            deltazk = -1.d0*(at%atom(i)%pos(3) - xyz_k(3))
                            drikdxi = -deltaxk/rik
                            drikdyi = -deltayk/rik
                            drikdzi = -deltazk/rik
                            drikdxk = -1.d0*drikdxi
                            drikdyk = -1.d0*drikdyi
                            drikdzk = -1.d0*drikdzi
                            drikdxj = 0.d0
                            drikdyj = 0.d0
                            drikdzj = 0.d0
                            fcutik=0.5d0*(dcos(pi*rik/cutoff)+1.d0)
                            temp1=0.5d0*(-dsin(pi*rik/cutoff))*(pi/cutoff)
                            dfcutikdxi=temp1*drikdxi
                            dfcutikdyi=temp1*drikdyi
                            dfcutikdzi=temp1*drikdzi
                            dfcutikdxj=0.0d0
                            dfcutikdyj=0.0d0
                            dfcutikdzj=0.0d0
                            dfcutikdxk=-1.d0*dfcutikdxi
                            dfcutikdyk=-1.d0*dfcutikdyi
                            dfcutikdzk=-1.d0*dfcutikdzi
                            rjk = (xyz_j(1) - xyz_k(1))**2 + (xyz_j(2) - xyz_k(2))**2 + (xyz_j(3) - xyz_k(3))**2
                            rjk = dsqrt(rjk)

                            if (rjk.gt.cutoff) cycle  ! CAUTAINS STUPID!!!
                            if (rjk < Rmin) then
                                print*, 'Rjk', rjk,' smaller than Rmin'
                                stop
                            endif
                            drjkdxj = (xyz_j(1) - xyz_k(1))/rjk
                            drjkdyj = (xyz_j(2) - xyz_k(2))/rjk
                            drjkdzj = (xyz_j(3) - xyz_k(3))/rjk
                            drjkdxk = -1.d0*drjkdxj
                            drjkdyk = -1.d0*drjkdyj
                            drjkdzk = -1.d0*drjkdzj
                            drjkdxi = 0.d0
                            drjkdyi = 0.d0
                            drjkdzi = 0.d0
                            fcutjk=0.5d0*(dcos(pi*rjk/cutoff)+1.d0)
                            temp1=0.5d0*(-dsin(pi*rjk/cutoff))*(pi/cutoff)
                            dfcutjkdxj=temp1*drjkdxj
                            dfcutjkdyj=temp1*drjkdyj
                            dfcutjkdzj=temp1*drjkdzj
                            dfcutjkdxk=-1.d0*dfcutjkdxj
                            dfcutjkdyk=-1.d0*dfcutjkdyj
                            dfcutjkdzk=-1.d0*dfcutjkdzj
                            dfcutjkdxi=0.0d0
                            dfcutjkdyi=0.0d0
                            dfcutjkdzi=0.0d0

                            f=rjk**2 - rij**2 -rik**2
                            g=-2.d0*rij*rik
                            costheta=f/g
                            !!!!  2^1-eta (1+lamda coseta_ijk)^eta 
                            !!!!  eta = 1 lamda = +1.d0
                            costheta=1.d0 + costheta
                            dfdxi=-2.d0*rij*drijdxi - 2.d0*rik*drikdxi
                            dfdyi=-2.d0*rij*drijdyi - 2.d0*rik*drikdyi
                            dfdzi=-2.d0*rij*drijdzi - 2.d0*rik*drikdzi

                            dfdxj=2.d0*rjk*drjkdxj - 2.d0*rij*drijdxj
                            dfdyj=2.d0*rjk*drjkdyj - 2.d0*rij*drijdyj
                            dfdzj=2.d0*rjk*drjkdzj - 2.d0*rij*drijdzj

                            dfdxk=2.d0*rjk*drjkdxk - 2.d0*rik*drikdxk
                            dfdyk=2.d0*rjk*drjkdyk - 2.d0*rik*drikdyk
                            dfdzk=2.d0*rjk*drjkdzk - 2.d0*rik*drikdzk

                            dgdxi=-2.d0*(drijdxi*rik + rij*drikdxi)
                            dgdyi=-2.d0*(drijdyi*rik + rij*drikdyi)
                            dgdzi=-2.d0*(drijdzi*rik + rij*drikdzi)

                            dgdxj=-2.d0*drijdxj*rik
                            dgdyj=-2.d0*drijdyj*rik
                            dgdzj=-2.d0*drijdzj*rik

                            dgdxk=-2.d0*rij*drikdxk
                            dgdyk=-2.d0*rij*drikdyk
                            dgdzk=-2.d0*rij*drikdzk

                            temp1=1.d0/g**2
                            dcosthetadxi=(dfdxi*g - f*dgdxi)*temp1
                            dcosthetadyi=(dfdyi*g - f*dgdyi)*temp1
                            dcosthetadzi=(dfdzi*g - f*dgdzi)*temp1
                            dcosthetadxj=(dfdxj*g - f*dgdxj)*temp1
                            dcosthetadyj=(dfdyj*g - f*dgdyj)*temp1
                            dcosthetadzj=(dfdzj*g - f*dgdzj)*temp1
                            dcosthetadxk=(dfdxk*g - f*dgdxk)*temp1
                            dcosthetadyk=(dfdyk*g - f*dgdyk)*temp1
                            dcosthetadzk=(dfdzk*g - f*dgdzk)*temp1
                            expxyz=dexp(-alpha*(rij**2+rik**2+rjk**2))
                            temp1=-alpha*2.0d0*expxyz
                            dexpxyzdxi=(rij*drijdxi+rik*drikdxi+rjk*drjkdxi)*temp1
                            dexpxyzdyi=(rij*drijdyi+rik*drikdyi+rjk*drjkdyi)*temp1
                            dexpxyzdzi=(rij*drijdzi+rik*drikdzi+rjk*drjkdzi)*temp1
                            dexpxyzdxj=(rij*drijdxj+rik*drikdxj+rjk*drjkdxj)*temp1
                            dexpxyzdyj=(rij*drijdyj+rik*drikdyj+rjk*drjkdyj)*temp1
                            dexpxyzdzj=(rij*drijdzj+rik*drikdzj+rjk*drjkdzj)*temp1
                            dexpxyzdxk=(rij*drijdxk+rik*drikdxk+rjk*drjkdxk)*temp1
                            dexpxyzdyk=(rij*drijdyk+rik*drikdyk+rjk*drjkdyk)*temp1
                            dexpxyzdzk=(rij*drijdzk+rik*drikdzk+rjk*drjkdzk)*temp1
                            at%xx(ii,i)=at%xx(ii,i)+costheta*expxyz*fcutij*fcutik*fcutjk
                            at%xx(ii + nnn,i)=at%xx(ii + nnn,i)+&
                            costheta*expxyz*fcutij*fcutik*fcutjk*weights_j*weights_k

                            temp1=(dcosthetadxi*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdxi*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdxi*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdxi*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdxi)
                            temp2=(dcosthetadxj*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdxj*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdxj*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdxj*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdxj)
                            temp3=(dcosthetadxk*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdxk*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdxk*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdxk*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdxk)
                            temp4 = temp1 * weights_j * weights_k
                            temp5 = temp2 * weights_j * weights_k
                            temp6 = temp3 * weights_j * weights_k
                            at%dxdy(ii,i,i,1)=at%dxdy(ii,i,i,1)+temp1
                            at%dxdy(ii,i,n,1)=at%dxdy(ii,i,n,1)+temp2
                            at%dxdy(ii,i,m,1)=at%dxdy(ii,i,m,1)+temp3
                            at%dxdy(ii + nnn,i,i,1)=at%dxdy(ii + nnn,i,i,1)+temp4
                            at%dxdy(ii + nnn,i,n,1)=at%dxdy(ii + nnn,i,n,1)+temp5
                            at%dxdy(ii + nnn,i,m,1)=at%dxdy(ii + nnn,i,m,1)+temp6

                            at%strs(1,1,ii,i)=at%strs(1,1,ii,i)+deltaxj*temp2+deltaxk*temp3
                            at%strs(2,1,ii,i)=at%strs(2,1,ii,i)+deltayj*temp2+deltayk*temp3
                            at%strs(3,1,ii,i)=at%strs(3,1,ii,i)+deltazj*temp2+deltazk*temp3
                            at%strs(1,1,ii + nnn,i)=at%strs(1,1,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                            at%strs(2,1,ii + nnn,i)=at%strs(2,1,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                            at%strs(3,1,ii + nnn,i)=at%strs(3,1,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                            ! dxxii/dy_i
                            temp1=(dcosthetadyi*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdyi*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdyi*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdyi*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdyi)
                            temp2=(dcosthetadyj*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdyj*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdyj*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdyj*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdyj)
                            temp3=(dcosthetadyk*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdyk*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdyk*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdyk*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdyk)
                            temp4 = temp1 * weights_j * weights_k
                            temp5 = temp2 * weights_j * weights_k
                            temp6 = temp3 * weights_j * weights_k
                            at%dxdy(ii,i,i,2)=at%dxdy(ii,i,i,2)+temp1
                            at%dxdy(ii,i,n,2)=at%dxdy(ii,i,n,2)+temp2
                            at%dxdy(ii,i,m,2)=at%dxdy(ii,i,m,2)+temp3

                            at%dxdy(ii + nnn,i,i,2)=at%dxdy(ii + nnn,i,i,2)+temp4
                            at%dxdy(ii + nnn,i,n,2)=at%dxdy(ii + nnn,i,n,2)+temp5
                            at%dxdy(ii + nnn,i,m,2)=at%dxdy(ii + nnn,i,m,2)+temp6
                            at%strs(1,2,ii,i)=at%strs(1,2,ii,i)+deltaxj*temp2+deltaxk*temp3
                            at%strs(2,2,ii,i)=at%strs(2,2,ii,i)+deltayj*temp2+deltayk*temp3
                            at%strs(3,2,ii,i)=at%strs(3,2,ii,i)+deltazj*temp2+deltazk*temp3

                            at%strs(1,2,ii + nnn,i)=at%strs(1,2,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                            at%strs(2,2,ii + nnn,i)=at%strs(2,2,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                            at%strs(3,2,ii + nnn,i)=at%strs(3,2,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                            ! dxxii/dz_i
                            temp1=(dcosthetadzi*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdzi*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdzi*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdzi*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdzi)
                            temp2=(dcosthetadzj*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdzj*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdzj*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdzj*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdzj)
                            temp3=(dcosthetadzk*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdzk*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdzk*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdzk*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdzk)
                            temp4 = temp1 * weights_j * weights_k
                            temp5 = temp2 * weights_j * weights_k
                            temp6 = temp3 * weights_j * weights_k
                            at%dxdy(ii,i,i,3)=at%dxdy(ii,i,i,3)+temp1
                            at%dxdy(ii,i,n,3)=at%dxdy(ii,i,n,3)+temp2
                            at%dxdy(ii,i,m,3)=at%dxdy(ii,i,m,3)+temp3

                            at%dxdy(ii + nnn,i,i,3)=at%dxdy(ii + nnn,i,i,3)+temp4
                            at%dxdy(ii + nnn,i,n,3)=at%dxdy(ii + nnn,i,n,3)+temp5
                            at%dxdy(ii + nnn,i,m,3)=at%dxdy(ii + nnn,i,m,3)+temp6
                            at%strs(1,3,ii,i)=at%strs(1,3,ii,i)+deltaxj*temp2+deltaxk*temp3
                            at%strs(2,3,ii,i)=at%strs(2,3,ii,i)+deltayj*temp2+deltayk*temp3
                            at%strs(3,3,ii,i)=at%strs(3,3,ii,i)+deltazj*temp2+deltazk*temp3

                            at%strs(1,3,ii + nnn,i)=at%strs(1,3,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                            at%strs(2,3,ii + nnn,i)=at%strs(2,3,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                            at%strs(3,3,ii + nnn,i)=at%strs(3,3,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                        enddo ! k_neighbor
                    enddo ! k_type       
                enddo ! j_neighbor
            enddo ! j_type
            print*, 'lllll',lllll
        enddo ! i
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
!G3 = SUM_j{exp(-alpha*(rij-rshift)**2)*fc(rij)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    elseif (ACSF%sf(ii)%ntype.eq.3) then
        cutoff = ACSF%sf(ii)%cutoff
        rshift = ACSF%sf(ii)%alpha
        alpha = 4.d0
        do i = 1, at%natoms
            do i_type = 1, nspecies
                do i_neighbor = 1, at%atom(i)%count(i_type)
                    rij = at%atom(i)%neighbor(i_type,i_neighbor,4)
                    xyz = at%atom(i)%neighbor(i_type,i_neighbor,1:3)
                    n = int(at%atom(i)%neighbor(i_type,i_neighbor,5))
                    !cutoff = ACSF%sf(ii)%cutoff
                    !alpha = ACSF%sf(ii)%alpha
                    weights = at%mlp_weights(n)
                    if (rij.gt.cutoff) cycle
                    deltaxj = -1.d0*(at%atom(i)%pos(1) - xyz(1))
                    deltayj = -1.d0*(at%atom(i)%pos(2) - xyz(2))
                    deltazj = -1.d0*(at%atom(i)%pos(3) - xyz(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    fcutij = 0.5d0 * (dcos(pi*rij/cutoff) + 1.d0)
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                    at%xx(ii,i)=at%xx(ii,i)+dexp(-1.d0*alpha*(rij-rshift)**2)*fcutij
                    at%xx(ii + nnn,i)=at%xx(ii + nnn,i)+dexp(-1.d0*alpha*(rij-rshift)**2)*fcutij*weights
                    temp1=-2.d0*alpha*(rij-rshift)
                    temp2=dexp(-1.d0*alpha*(rij-rshift)**2)
                    ! dxx/dx
                    at%dxdy(ii,i,i,1)=at%dxdy(ii,i,i,1)+&
                           (temp1*drijdxi*temp2*fcutij&
                          + temp2*dfcutijdxi)

                    at%dxdy(ii + nnn,i,i,1)=at%dxdy(ii + nnn,i,i,1)+&
                           (temp1*drijdxi*temp2*fcutij&
                          + temp2*dfcutijdxi)*weights
                    temp3=temp1*drijdxj*temp2*fcutij + temp2*dfcutijdxj
                    at%dxdy(ii,i,n,1)=at%dxdy(ii,i,n,1)+temp3
                    temp4 = temp3 * weights
                    at%dxdy(ii + nnn,i,n,1)=at%dxdy(ii + nnn,i,n,1)+temp4
                    at%strs(1,1,ii,i)=at%strs(1,1,ii,i)+deltaxj*temp3
                    at%strs(2,1,ii,i)=at%strs(2,1,ii,i)+deltayj*temp3
                    at%strs(3,1,ii,i)=at%strs(3,1,ii,i)+deltazj*temp3
                    at%strs(1,1,ii + nnn,i)=at%strs(1,1,ii + nnn,i)+deltaxj*temp4
                    at%strs(2,1,ii + nnn,i)=at%strs(2,1,ii + nnn,i)+deltayj*temp4
                    at%strs(3,1,ii + nnn,i)=at%strs(3,1,ii + nnn,i)+deltazj*temp4
                    ! dxx/dy
                    at%dxdy(ii,i,i,2)=at%dxdy(ii,i,i,2)+&
                           (temp1*drijdyi*temp2*fcutij&
                          + temp2*dfcutijdyi)
                    at%dxdy(ii + nnn,i,i,2)=at%dxdy(ii + nnn,i,i,2)+&
                           (temp1*drijdyi*temp2*fcutij&
                          + temp2*dfcutijdyi)*weights
                    temp3= temp1*drijdyj*temp2*fcutij + temp2*dfcutijdyj
                    at%dxdy(ii,i,n,2)=at%dxdy(ii,i,n,2)+temp3
                    temp4 = temp3 * weights
                    at%dxdy(ii + nnn,i,n,2)=at%dxdy(ii + nnn,i,n,2)+temp4
                    at%strs(1,2,ii,i)=at%strs(1,2,ii,i)+deltaxj*temp3
                    at%strs(2,2,ii,i)=at%strs(2,2,ii,i)+deltayj*temp3
                    at%strs(3,2,ii,i)=at%strs(3,2,ii,i)+deltazj*temp3

                    at%strs(1,2,ii + nnn,i)=at%strs(1,2,ii + nnn,i)+deltaxj*temp4
                    at%strs(2,2,ii + nnn,i)=at%strs(2,2,ii + nnn,i)+deltayj*temp4
                    at%strs(3,2,ii + nnn,i)=at%strs(3,2,ii + nnn,i)+deltazj*temp4
                    ! dxx/dz
                    at%dxdy(ii,i,i,3)=at%dxdy(ii,i,i,3)+&
                           (temp1*drijdzi*temp2*fcutij&
                          + temp2*dfcutijdzi)
                    at%dxdy(ii + nnn,i,i,3)=at%dxdy(ii + nnn,i,i,3)+&
                           (temp1*drijdzi*temp2*fcutij&
                          + temp2*dfcutijdzi)*weights
                    temp3=temp1*drijdzj*temp2*fcutij + temp2*dfcutijdzj
                    at%dxdy(ii,i,n,3)=at%dxdy(ii,i,n,3)+temp3
                    temp4 = temp3 * weights
                    at%dxdy(ii + nnn,i,n,3)=at%dxdy(ii + nnn,i,n,3)+temp4
                    at%strs(1,3,ii,i)=at%strs(1,3,ii,i)+deltaxj*temp3
                    at%strs(2,3,ii,i)=at%strs(2,3,ii,i)+deltayj*temp3
                    at%strs(3,3,ii,i)=at%strs(3,3,ii,i)+deltazj*temp3

                    at%strs(1,3,ii + nnn,i)=at%strs(1,3,ii + nnn,i)+deltaxj*temp4
                    at%strs(2,3,ii + nnn,i)=at%strs(2,3,ii + nnn,i)+deltayj*temp4
                    at%strs(3,3,ii + nnn,i)=at%strs(3,3,ii + nnn,i)+deltazj*temp4
                enddo ! i_neighbor
            enddo ! i_type
        enddo ! i
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 
! lamda = -1.d0
! eta = 1
! G2 = SUM_jk{(1+lamda*costheta_ijk)^eta*
! exp(-alpha*(rij**2+rik**2+rjk**2))*fc(rij)*fc(rik)*fc(rjk)}
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    elseif (ACSF%sf(ii)%ntype.eq.4) then
        cutoff = ACSF%sf(ii)%cutoff
        alpha = ACSF%sf(ii)%alpha
        do i = 1, at%natoms
            do j_type = 1, nspecies
                do j_neighbor = 1, at%atom(i)%count(j_type)
                    rij = at%atom(i)%neighbor(j_type,j_neighbor,4)
                    if (rij.gt.cutoff) cycle
                    xyz_j = at%atom(i)%neighbor(j_type,j_neighbor,1:3)
                    n = int(at%atom(i)%neighbor(j_type,j_neighbor,5))
                    weights_j = at%mlp_weights(n)
                    deltaxj = -1.d0*(at%atom(i)%pos(1) - xyz_j(1))
                    deltayj = -1.d0*(at%atom(i)%pos(2) - xyz_j(2))
                    deltazj = -1.d0*(at%atom(i)%pos(3) - xyz_j(3))
                    drijdxi = -1.d0*deltaxj/rij
                    drijdyi = -1.d0*deltayj/rij
                    drijdzi = -1.d0*deltazj/rij
                    drijdxj = -1.d0*drijdxi
                    drijdyj = -1.d0*drijdyi
                    drijdzj = -1.d0*drijdzi
                    drijdxk = 0.d0
                    drijdyk = 0.d0
                    drijdzk = 0.d0

                    fcutij=0.5d0*(dcos(pi*rij/cutoff)+1.d0)
                    temp1=0.5d0*(-dsin(pi*rij/cutoff))*(pi/cutoff)
                    dfcutijdxi=temp1*drijdxi
                    dfcutijdyi=temp1*drijdyi
                    dfcutijdzi=temp1*drijdzi
                    dfcutijdxj=-1.d0*dfcutijdxi
                    dfcutijdyj=-1.d0*dfcutijdyi
                    dfcutijdzj=-1.d0*dfcutijdzi
                    dfcutijdxk=0.0d0
                    dfcutijdyk=0.0d0
                    dfcutijdzk=0.0d0
                    do k_type = 1, nspecies
                        do k_neighbor = 1, at%atom(i)%count(k_type)
                            if ((k_type <= j_type) .and. (k_neighbor <= j_neighbor)) cycle
                            rik = at%atom(i)%neighbor(k_type,k_neighbor,4)
                            if (rik.gt.cutoff) cycle
                            xyz_k = at%atom(i)%neighbor(k_type,k_neighbor,1:3)
                            m = int(at%atom(i)%neighbor(k_type,k_neighbor,5))
                            weights_k = at%mlp_weights(m)

                            deltaxk = -1.d0*(at%atom(i)%pos(1) - xyz_k(1))
                            deltayk = -1.d0*(at%atom(i)%pos(2) - xyz_k(2))
                            deltazk = -1.d0*(at%atom(i)%pos(3) - xyz_k(3))
                            drikdxi = -deltaxk/rik
                            drikdyi = -deltayk/rik
                            drikdzi = -deltazk/rik
                            drikdxk = -1.d0*drikdxi
                            drikdyk = -1.d0*drikdyi
                            drikdzk = -1.d0*drikdzi
                            drikdxj = 0.d0
                            drikdyj = 0.d0
                            drikdzj = 0.d0
                            fcutik=0.5d0*(dcos(pi*rik/cutoff)+1.d0)
                            temp1=0.5d0*(-dsin(pi*rik/cutoff))*(pi/cutoff)
                            dfcutikdxi=temp1*drikdxi
                            dfcutikdyi=temp1*drikdyi
                            dfcutikdzi=temp1*drikdzi
                            dfcutikdxj=0.0d0
                            dfcutikdyj=0.0d0
                            dfcutikdzj=0.0d0
                            dfcutikdxk=-1.d0*dfcutikdxi
                            dfcutikdyk=-1.d0*dfcutikdyi
                            dfcutikdzk=-1.d0*dfcutikdzi
                            rjk = (xyz_j(1) - xyz_k(1))**2 + (xyz_j(2) - xyz_k(2))**2 + (xyz_j(3) - xyz_k(3))**2
                            rjk = dsqrt(rjk)

                            if (rjk.gt.cutoff) cycle  ! Be careful STUPID!!!
                            if (rjk < Rmin) then
                                print*, 'Rjk', rjk,' smaller than Rmin'
                                stop
                            endif
                            drjkdxj = (xyz_j(1) - xyz_k(1))/rjk
                            drjkdyj = (xyz_j(2) - xyz_k(2))/rjk
                            drjkdzj = (xyz_j(3) - xyz_k(3))/rjk
                            drjkdxk = -1.d0*drjkdxj
                            drjkdyk = -1.d0*drjkdyj
                            drjkdzk = -1.d0*drjkdzj
                            drjkdxi = 0.d0
                            drjkdyi = 0.d0
                            drjkdzi = 0.d0
                            fcutjk=0.5d0*(dcos(pi*rjk/cutoff)+1.d0)
                            temp1=0.5d0*(-dsin(pi*rjk/cutoff))*(pi/cutoff)
                            dfcutjkdxj=temp1*drjkdxj
                            dfcutjkdyj=temp1*drjkdyj
                            dfcutjkdzj=temp1*drjkdzj
                            dfcutjkdxk=-1.d0*dfcutjkdxj
                            dfcutjkdyk=-1.d0*dfcutjkdyj
                            dfcutjkdzk=-1.d0*dfcutjkdzj
                            dfcutjkdxi=0.0d0
                            dfcutjkdyi=0.0d0
                            dfcutjkdzi=0.0d0

                            f=rjk**2 - rij**2 -rik**2
                            g=-2.d0*rij*rik
                            costheta=f/g
                            costheta=1.d0 - costheta  ! avoid negative values
                            dfdxi=-2.d0*rij*drijdxi - 2.d0*rik*drikdxi
                            dfdyi=-2.d0*rij*drijdyi - 2.d0*rik*drikdyi
                            dfdzi=-2.d0*rij*drijdzi - 2.d0*rik*drikdzi

                            dfdxj=2.d0*rjk*drjkdxj - 2.d0*rij*drijdxj
                            dfdyj=2.d0*rjk*drjkdyj - 2.d0*rij*drijdyj
                            dfdzj=2.d0*rjk*drjkdzj - 2.d0*rij*drijdzj

                            dfdxk=2.d0*rjk*drjkdxk - 2.d0*rik*drikdxk
                            dfdyk=2.d0*rjk*drjkdyk - 2.d0*rik*drikdyk
                            dfdzk=2.d0*rjk*drjkdzk - 2.d0*rik*drikdzk

                            dgdxi=-2.d0*(drijdxi*rik + rij*drikdxi)
                            dgdyi=-2.d0*(drijdyi*rik + rij*drikdyi)
                            dgdzi=-2.d0*(drijdzi*rik + rij*drikdzi)

                            dgdxj=-2.d0*drijdxj*rik
                            dgdyj=-2.d0*drijdyj*rik
                            dgdzj=-2.d0*drijdzj*rik

                            dgdxk=-2.d0*rij*drikdxk
                            dgdyk=-2.d0*rij*drikdyk
                            dgdzk=-2.d0*rij*drikdzk

                            temp1=1.d0/g**2
                            !!!! Be careful costheta = 1.d0 - costheta 2019.07.25
                            dcosthetadxi=-1.d0 * (dfdxi*g - f*dgdxi)*temp1  
                            dcosthetadyi=-1.d0 * (dfdyi*g - f*dgdyi)*temp1 
                            dcosthetadzi=-1.d0 * (dfdzi*g - f*dgdzi)*temp1 
                            dcosthetadxj=-1.d0 * (dfdxj*g - f*dgdxj)*temp1 
                            dcosthetadyj=-1.d0 * (dfdyj*g - f*dgdyj)*temp1 
                            dcosthetadzj=-1.d0 * (dfdzj*g - f*dgdzj)*temp1 
                            dcosthetadxk=-1.d0 * (dfdxk*g - f*dgdxk)*temp1 
                            dcosthetadyk=-1.d0 * (dfdyk*g - f*dgdyk)*temp1 
                            dcosthetadzk=-1.d0 * (dfdzk*g - f*dgdzk)*temp1 

                            expxyz=dexp(-alpha*(rij**2+rik**2+rjk**2))
                            temp1=-alpha*2.0d0*expxyz
                            dexpxyzdxi=(rij*drijdxi+rik*drikdxi+rjk*drjkdxi)*temp1
                            dexpxyzdyi=(rij*drijdyi+rik*drikdyi+rjk*drjkdyi)*temp1
                            dexpxyzdzi=(rij*drijdzi+rik*drikdzi+rjk*drjkdzi)*temp1
                            dexpxyzdxj=(rij*drijdxj+rik*drikdxj+rjk*drjkdxj)*temp1
                            dexpxyzdyj=(rij*drijdyj+rik*drikdyj+rjk*drjkdyj)*temp1
                            dexpxyzdzj=(rij*drijdzj+rik*drikdzj+rjk*drjkdzj)*temp1
                            dexpxyzdxk=(rij*drijdxk+rik*drikdxk+rjk*drjkdxk)*temp1
                            dexpxyzdyk=(rij*drijdyk+rik*drikdyk+rjk*drjkdyk)*temp1
                            dexpxyzdzk=(rij*drijdzk+rik*drikdzk+rjk*drjkdzk)*temp1

                            at%xx(ii,i)=at%xx(ii,i)+costheta*expxyz*fcutij*fcutik*fcutjk
                            at%xx(ii + nnn,i)=at%xx(ii + nnn,i)+&
                            costheta*expxyz*fcutij*fcutik*fcutjk*weights_j*weights_k

                            temp1=(dcosthetadxi*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdxi*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdxi*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdxi*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdxi)
                            temp2=(dcosthetadxj*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdxj*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdxj*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdxj*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdxj)
                            temp3=(dcosthetadxk*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdxk*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdxk*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdxk*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdxk)
                            temp4 = temp1 * weights_j * weights_k
                            temp5 = temp2 * weights_j * weights_k
                            temp6 = temp3 * weights_j * weights_k
                            at%dxdy(ii,i,i,1)=at%dxdy(ii,i,i,1)+temp1
                            at%dxdy(ii,i,n,1)=at%dxdy(ii,i,n,1)+temp2
                            at%dxdy(ii,i,m,1)=at%dxdy(ii,i,m,1)+temp3
                            at%dxdy(ii + nnn,i,i,1)=at%dxdy(ii + nnn,i,i,1)+temp4
                            at%dxdy(ii + nnn,i,n,1)=at%dxdy(ii + nnn,i,n,1)+temp5
                            at%dxdy(ii + nnn,i,m,1)=at%dxdy(ii + nnn,i,m,1)+temp6

                            at%strs(1,1,ii,i)=at%strs(1,1,ii,i)+deltaxj*temp2+deltaxk*temp3
                            at%strs(2,1,ii,i)=at%strs(2,1,ii,i)+deltayj*temp2+deltayk*temp3
                            at%strs(3,1,ii,i)=at%strs(3,1,ii,i)+deltazj*temp2+deltazk*temp3
                            at%strs(1,1,ii + nnn,i)=at%strs(1,1,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                            at%strs(2,1,ii + nnn,i)=at%strs(2,1,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                            at%strs(3,1,ii + nnn,i)=at%strs(3,1,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                            ! dxxii/dy_i
                            temp1=(dcosthetadyi*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdyi*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdyi*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdyi*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdyi)
                            temp2=(dcosthetadyj*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdyj*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdyj*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdyj*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdyj)
                            temp3=(dcosthetadyk*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdyk*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdyk*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdyk*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdyk)
                            temp4 = temp1 * weights_j * weights_k
                            temp5 = temp2 * weights_j * weights_k
                            temp6 = temp3 * weights_j * weights_k
                            at%dxdy(ii,i,i,2)=at%dxdy(ii,i,i,2)+temp1
                            at%dxdy(ii,i,n,2)=at%dxdy(ii,i,n,2)+temp2
                            at%dxdy(ii,i,m,2)=at%dxdy(ii,i,m,2)+temp3

                            at%dxdy(ii + nnn,i,i,2)=at%dxdy(ii + nnn,i,i,2)+temp4
                            at%dxdy(ii + nnn,i,n,2)=at%dxdy(ii + nnn,i,n,2)+temp5
                            at%dxdy(ii + nnn,i,m,2)=at%dxdy(ii + nnn,i,m,2)+temp6
                            at%strs(1,2,ii,i)=at%strs(1,2,ii,i)+deltaxj*temp2+deltaxk*temp3
                            at%strs(2,2,ii,i)=at%strs(2,2,ii,i)+deltayj*temp2+deltayk*temp3
                            at%strs(3,2,ii,i)=at%strs(3,2,ii,i)+deltazj*temp2+deltazk*temp3

                            at%strs(1,2,ii + nnn,i)=at%strs(1,2,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                            at%strs(2,2,ii + nnn,i)=at%strs(2,2,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                            at%strs(3,2,ii + nnn,i)=at%strs(3,2,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                            ! dxxii/dz_i
                            temp1=(dcosthetadzi*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdzi*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdzi*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdzi*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdzi)
                            temp2=(dcosthetadzj*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdzj*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdzj*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdzj*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdzj)
                            temp3=(dcosthetadzk*expxyz*fcutij*fcutik*fcutjk&
                                  +costheta*dexpxyzdzk*fcutij*fcutik*fcutjk&
                                  +costheta*expxyz*dfcutijdzk*fcutik*fcutjk&
                                  +costheta*expxyz*fcutij*dfcutikdzk*fcutjk&
                                  +costheta*expxyz*fcutij*fcutik*dfcutjkdzk)
                            temp4 = temp1 * weights_j * weights_k
                            temp5 = temp2 * weights_j * weights_k
                            temp6 = temp3 * weights_j * weights_k
                            at%dxdy(ii,i,i,3)=at%dxdy(ii,i,i,3)+temp1
                            at%dxdy(ii,i,n,3)=at%dxdy(ii,i,n,3)+temp2
                            at%dxdy(ii,i,m,3)=at%dxdy(ii,i,m,3)+temp3

                            at%dxdy(ii + nnn,i,i,3)=at%dxdy(ii + nnn,i,i,3)+temp4
                            at%dxdy(ii + nnn,i,n,3)=at%dxdy(ii + nnn,i,n,3)+temp5
                            at%dxdy(ii + nnn,i,m,3)=at%dxdy(ii + nnn,i,m,3)+temp6
                            at%strs(1,3,ii,i)=at%strs(1,3,ii,i)+deltaxj*temp2+deltaxk*temp3
                            at%strs(2,3,ii,i)=at%strs(2,3,ii,i)+deltayj*temp2+deltayk*temp3
                            at%strs(3,3,ii,i)=at%strs(3,3,ii,i)+deltazj*temp2+deltazk*temp3

                            at%strs(1,3,ii + nnn,i)=at%strs(1,3,ii + nnn,i)+deltaxj*temp5+deltaxk*temp6
                            at%strs(2,3,ii + nnn,i)=at%strs(2,3,ii + nnn,i)+deltayj*temp5+deltayk*temp6
                            at%strs(3,3,ii + nnn,i)=at%strs(3,3,ii + nnn,i)+deltazj*temp5+deltazk*temp6
                        enddo ! k_neighbor
                    enddo ! k_type       
                enddo ! j_neighbor
            enddo ! j_type
        enddo ! i
    else
        print *, 'Unknown function type',ii, ACSF%sf(ii)%ntype
    endif
enddo  ! types
END SUBROUTINE 



    



END MODULE
