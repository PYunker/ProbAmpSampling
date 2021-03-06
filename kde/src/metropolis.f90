!------------------------------------------------------------------------------
! MODULE: metropolis
!
!> @author
!> Pavel Junker
!
! DESCRIPTION: 
!>  a simple implementation of Metropolis-Hastings sampling algorithm
!
! REVISION HISTORY:
! 13.03.2021 - Initial Version
!------------------------------------------------------------------------------
module metropolis
	use omp_lib
	use distributions, only : rn_to_r
	implicit none
	private
	integer, parameter :: DP = kind(0.0D0)
	
	public :: draw_sample

contains

	subroutine draw_sample(sample, sample_count, sample_dim, pdf, &
	                       separation_arg, scale_arg, initial_arg)
		integer, intent(in) :: sample_count, sample_dim
		integer, intent(in), optional :: separation_arg
		real(kind=DP), intent(in), optional :: scale_arg, initial_arg(sample_dim)
		real(kind=DP), intent(out) :: sample(sample_dim, sample_count)
		procedure(rn_to_r) :: pdf
		! locals
		real(kind=DP) :: walker(sample_dim), proposed(sample_dim), lam
		real(kind=DP), allocatable :: u(:,:), v(:)		
		integer :: i, j, thread_count, separation
		! for contigous verison
!		integer :: rank, offset, thread_load
		
		! every 'separation' steps, walker's current position is added to the
		! sample (default value is 100)
		if (present(separation_arg)) then
			separation = separation_arg
		else
			separation = 100
		end if

		allocate(v(separation))
		allocate(u(sample_dim,separation))

		! spawn walker at either zero (default) or user defined position
		if (present(initial_arg)) then
			walker = initial_arg
		else
			walker = 0
		end if
		
		! 'lam' scales length of leaps walker makes with each iteration
		! for lam = 1 (default value), they are rouhly normally distributed
		lam = 0.61477929423D0
		if (present(scale_arg)) lam = lam * scale_arg    
		
		! ======================= NONCONTIGUOUS VERSION =======================

		! threads output to non-contiguous sections of 'sample', so that
		! adjacent samples aren't corelated (and any subset of sample
		! is as good as if picked randomly)
		!$OMP PARALLEL PRIVATE(u,v,i,thread_count,walker,proposed)
		thread_count = omp_get_num_threads()
		i = omp_get_thread_num()
		
		do while(i < sample_count)
			call random_number(v)
			call random_number(u)
			! tranformation below generates rougly normal sample from uniform
			! one. it is in fact needlesly precise, so approximating the log-
			! arithm for higher performance should be OK
			u = lam * log(u/(1-u))
			do j=1,separation
				proposed = walker + u(:,j)
				if (pdf(proposed)/pdf(walker) > v(j)) walker = proposed
			end do
			sample(:,i+1) = walker
			i = i + thread_count
		end do
		!$OMP END PARALLEL

		! ======================== CONTIGUOUS VERSION =========================
		! if, for whatever reason, all samples generated by one thread had to
		! be in contiguos section of 'sample', code below does just that

!		!$OMP PARALLEL PRIVATE(u,v,i,thread_count,thread_load,rank,walker,proposed,offset)
!		thread_count = omp_get_num_threads()
!		rank = omp_get_thread_num()
!		offset = rank * (sample_count / thread_count) + &
!		         min(mod(sample_count, thread_count), rank)
!		thread_load = sample_count / thread_count
!		if (rank < mod(sample_count, thread_count)) thread_load = thread_load + 1
!
!		do i=1,thread_load
!			call random_number(v)
!			call random_number(u)
!			u = lam * log(u/(1-u))
!			do j=1,separation
!				proposed = walker + u(:,j)
!				if (pdf(proposed)/pdf(walker) > v(j)) walker = proposed
!			end do
!			sample(:,offset + i) = walker
!		end do
!		!$OMP END PARALLEL

	end subroutine draw_sample

end module metropolis
