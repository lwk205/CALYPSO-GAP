Program  test_nGAP
use constants
use io
use struct
use gpr_main
implicit none
integer            :: i,j,k,ii,jj,kk
integer            :: na
integer            :: nconfig
real(dp)           :: fc_i, fc_j

call read_input()
open(2211,file='config')
read(2211,*) nconfig
allocate(at(nconfig))
do i= 1, nconfig
    read(2211,*)  na, nspecies
    call ini_structure(at(i), na, nspecies)
    do j = 1,3
        read(2211,*) at(i)%lat(j,:)
    enddo
    read(2211,*) at(i)%stress(:)
    do j = 1, at(i)%natoms
        read(2211,*) at(i)%symbols(j), at(i)%pos(j,:), at(i)%force(j,:)
    enddo
    read(2211,*) at(i)%energy_ref
    call build_neighbor(at(i), elements)
enddo
close(2211)
call ini_gap(nconfig)
call ini_gap_2b()
!open(2211,file='11.dat')
!    write(2211,*) at(1)%atom(1)%pos
!    write(2211,*) at(1)%atom(1)%count(1)
!    do i = 1 , at(1)%atom(1)%count(1)
!        write(2211, '(4F10.5)') at(1)%atom(1)%neighbor(1,i,:)
!    enddo
!close(2211)
!open(2211,file='22.dat')
!    write(2211,*) at(1)%atom(1)%pos
!    write(2211,*) at(1)%atom(1)%count(2)
!    do i = 1 , at(1)%atom(1)%count(2)
!        write(2211, '(4F10.5)') at(1)%atom(1)%neighbor(2,i,:)
!    enddo
!close(2211)

! Build matrix cmo
do i = 1, nsparse
    do j = 1, nconfig
        do k = 1, ninteraction
            cmo(i,j,k) = 0.d0
            do ii = 1, at(j)%natoms
                do jj = 1, at(j)%atom(ii)%count(k)
                    fc_i = fcutij(sparseX(i))
                    fc_j = fcutij(at(j)%atom(ii)%neighbor(k,jj,4))
                    cmo(i,j,k) = cmo(i,j,k) + &
       covariance(sparseX(i), at(j)%atom(ii)%neighbor(k,jj,4)) * fc_i * fc_j
                enddo
            enddo
        enddo
    enddo
enddo

do i = 1,nconfig
    obe(i) = at(i)%energy_ref - at(i)%natoms * ene_cons
    at(i)%sigma_e = sigma_e * sqrt(1.d0 * at(i)%natoms)
    lamda(i) = at(i)%sigma_e**2
    lamdaobe(i) = obe(i) * sqrt((1.0/lamda(i)))
enddo

do k = 1, ninteraction
    call matmuldiag_T(cmo(:,:,k),sqrt(1.0/lamda))
    call gpr(cmm, cmo(:,:,k), lamdaobe, coeff(:,k))
enddo
open(2234,file='coeffx.dat')
do i = 1,nsparse
    sparsecut(i) = fcutij(sparseX(i))
    write(2234,'(I3,F25.8,$)') i, sparseX(i)
    do k = 1,ninteraction
        write(2234,'(F25.8,$)') coeff(k,:)
    enddo
    write(2234,'(F25.8)') sparsecut(i)
enddo
close(2234)
end program
