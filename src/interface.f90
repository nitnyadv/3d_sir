module sirMod
use iso_c_binding, only: c_int, c_float, c_double, c_char

implicit none

integer, parameter :: kt=400      !maximum number of depth points (64)
integer, parameter :: kn=400      !maximum number of nodes (64)
integer, parameter :: kl=10       !maximum number of lines (100)
integer, parameter :: kld=5000    !maximum number of wavelengths (600)
integer, parameter :: mfitmax=200 !maximum number of total nodes (200)
integer, parameter :: kld4=4*kld, kldt=kld*kn, kldt4=4*kldt, kt8=8*kt+2, kl4=4*kl

type configuration
	integer ntl,nlin(kl),npas(kl),nble(kl)
	real*4 dlamda(kld)
	integer ntls,nlins(kl4),npass(kl4)
	real*4 dlamdas(kld4)
	real*4 abu(92)
	
	character*2 atom_all(kl)
	integer istage_all(kl)
    real*4 wlengt_all(kl)
    real*4 zeff_all(kl)
	real*4 energy_all(kl)
	real*4 loggf_all(kl)
	integer mult_all(2,kl)
	character*1 design_all(2,kl)
	real*4 tam_all(2,kl)
	real*4 alfa_all(kl)
	real*4 sigma_all(kl)

end type configuration

type(configuration) :: conf(10)

contains

	subroutine c_init(index, nchar, file_lines, nLambda) bind(c)
	integer(c_int), intent(in) :: index, nchar
	character(c_char), intent(in) :: file_lines(nchar)
	integer(c_int), intent(out) :: nLambda


	integer :: i, j, ifiltro
	integer ntl,nlin(kl),npas(kl),nble(kl)
	real*4 dlamda(kld)
	integer ntls,nlins(kl4),npass(kl4)
	real*4 dlamdas(kld4), eps(92)
	character*2 atom
	integer istage
	real*4 wlengt
	real*4 zeff
	real*4 energy
	real*4 loggf
	integer mult(2)
	character*1 design(2)
	real*4 tam(2)
	real*4 alfa
	real*4 sigma

	integer :: ixx, iln, ible, nxx

	common/Malla/ntl,nlin,npas,nble,dlamda
    common/Malla4/ntls,nlins,npass,dlamdas  !common para StokesFRsub
	common/ifiltro/ifiltro
	common/abundances/eps



		call leyendo

		!call lee_all_lines

! contamos el numero de puntos	
		nLambda = 0
		do i=1,ntl
        	do j=1,npas(i)
	      		nLambda = nLambda + 1
	    	end do			
		end do
		

		ifiltro = 0

		conf(index)%ntl = ntl
		conf(index)%nlin = nlin
		conf(index)%npas = npas
		conf(index)%nble = nble
		conf(index)%dlamda = dlamda
		conf(index)%ntls = ntls
		conf(index)%nlins = nlins
		conf(index)%npass = npass
		conf(index)%dlamdas = dlamdas
		conf(index)%abu = eps


        ixx=0
        do iln=1,ntl 
           do ible=1,nble(iln)
             ixx=ixx+1
             nxx=nlin(ixx) 
             if(nxx.eq.0)then
                nxx=nlin(ixx-1)
                call leelineasii(file_lines(1:nchar),nxx,atom,istage,wlengt,zeff,energy,loggf,mult,design,tam,alfa,sigma)
                loggf=-20.
                wlengt=5000.
             else
                call leelineasii(file_lines(1:nchar),nxx,atom,istage,wlengt,zeff,energy,loggf,mult,design,tam,alfa,sigma)
             endif 
             
             conf(index)%atom_all(ixx)=atom
             conf(index)%istage_all(ixx)=istage
             conf(index)%wlengt_all(ixx)=wlengt
             conf(index)%zeff_all(ixx)=zeff
             conf(index)%energy_all(ixx)=energy
             conf(index)%loggf_all(ixx)=loggf
             conf(index)%mult_all(1,ixx)=mult(1)
             conf(index)%mult_all(2,ixx)=mult(2)
             conf(index)%design_all(1,ixx)=design(1)
             conf(index)%design_all(2,ixx)=design(2)
             conf(index)%tam_all(1,ixx)=tam(1)
             conf(index)%tam_all(2,ixx)=tam(2)
             conf(index)%alfa_all(ixx)=alfa
             conf(index)%sigma_all(ixx)=sigma
             
           enddo
        enddo   

	end subroutine c_init

	subroutine c_setpsf(nPSF, xPSF, yPSF) bind(c)
	integer(c_int), intent(in) :: nPSF
	real(c_float), intent(in) :: xPSF(nPSF), yPSF(nPSF)
	integer :: i, j
	integer, parameter :: nmx=401
	real*4 x(nmx), y(nmx)
	character*100 filtro
	integer ifiltro, num
	common/filtro/filtro,x,y,num                 !para pasar el nombre de la PSF
    common/ifiltro/ifiltro
    	
		ifiltro = 1
    	do i = 1, nPSF
    		x(i) = xPSF(i)
    		y(i) = yPSF(i)
    	enddo
    	num = nPSF
	
	end subroutine c_setpsf


	subroutine c_synth(index, nDepth, nLambda, macroturbulence, model, stokes, error) bind(c)
	integer(c_int), intent(in) :: index, nDepth, nLambda
	real(c_double), intent(in) :: model(8,ndepth)
	real(c_double), intent(in) :: macroturbulence
	real(c_double), intent(out) :: stokes(5,nLambda)
	integer(c_int), intent(out) :: error
	
	real*4 stok(kld4)
    real*4 rt(kldt4),rp(kldt4),rh(kldt4),rv(kldt4)
    real*4 rg(kldt4),rf(kldt4),rm(kldt4), rmac(kld4)
    integer ist(4),i,k,ntot, j, l, itau
	character*100 Stokesfilename
	integer*4 mnodos(18), ntau
	real*4 atmosmodel(kt8), pesostray
	real*4 tau(kt),t(kt),pe(kt),pg(kt),z(kt),ro(kt)
	real*4 voffset,xmu

	integer ntl,nlin(kl),npas(kl),nble(kl)
	real*4 dlamda(kld)
	integer ntls,nlins(kl4),npass(kl4)
	real*4 dlamdas(kld4)

	character*2 atom_all(kl)
	integer istage_all(kl)
    real*4 wlengt_all(kl)
    real*4 zeff_all(kl)
	real*4 energy_all(kl)
	real*4 loggf_all(kl)
	integer mult_all(2,kl)
	character*1 design_all(2,kl)
	real*4 tam_all(2,kl)
	real*4 alfa_all(kl)
	real*4 sigma_all(kl)

	integer :: error_code
    common/Error/error_code

    common/OutputStokes/Stokesfilename

    common/Atmosmodel/atmosmodel,ntau !common para StokesFRsub
	common/numeronodos/mnodos         !para StokesFRsub
    common/offset/voffset             !para StokesFRsub
    common/anguloheliocent/xmu        !para StokesFRsub

	common/Malla/ntl,nlin,npas,nble,dlamda  !common para StokesFRsub
    common/Malla4/ntls,nlins,npass,dlamdas  !common para StokesFRsub
	common/Lineas_all/atom_all,istage_all,wlengt_all,zeff_all,energy_all,loggf_all,mult_all,design_all,tam_all,alfa_all,sigma_all

		atmosmodel = 0
		error = 0
		error_code = 0

		ntl = conf(index)%ntl
		nlin = conf(index)%nlin
		npas = conf(index)%npas
		nble = conf(index)%nble
		dlamda = conf(index)%dlamda
		ntls = conf(index)%ntls
		nlins = conf(index)%nlins
		npass = conf(index)%npass
		dlamdas = conf(index)%dlamdas

		atom_all = conf(index)%atom_all
		istage_all = conf(index)%istage_all
		wlengt_all = conf(index)%wlengt_all
		zeff_all = conf(index)%zeff_all
		energy_all = conf(index)%energy_all
		loggf_all = conf(index)%loggf_all
		mult_all = conf(index)%mult_all
		design_all = conf(index)%design_all
		tam_all = conf(index)%tam_all
		alfa_all = conf(index)%alfa_all
		sigma_all = conf(index)%sigma_all

	    ntau = nDepth

! offset de velocidad para perturbaciones relativas necesitamos que la velocidad sea siempre positiva        
		voffset=-15.e5    !cm/s
	    xmu=1.            !coseno del angulo heliocentrico	

! Put the model in vectorized form
		atmosmodel(8*ntau+1) = macroturbulence
		atmosmodel(8*ntau+2) = 1.0   ! filling
		pesostray = 1.0              ! stray
		do i = 1, ntau
			do j = 0, 7
				atmosmodel(i+j*ntau) = model(j+1,i)				
			enddo
			tau(i) = atmosmodel(i)
			t(i) = atmosmodel(i+ntau)
			pe(i) = atmosmodel(i+2*ntau)
		enddo

! pasamos los angulos a radianes
		call taulinea(0,1.,1,0.,atmosmodel,ntau)
	
! definimos los nodos en todos los puntos (excepto para ls presion elctronica)
		do i=1,8                 
        	mnodos(i)=0
		end do  
    	mnodos(2)=0

! Compute hydrostatic equilibrium if necessary
    	if (minval(model(3,:)) == -1) then
    		call equisubmu(ntau,tau,t,pe,pg,z,ro)

			if (error_code /= 0) then
				error = error_code
				return
			endif
 
        	do i=1,ntau
            	atmosmodel(i+2*ntau)=pe(i)				
        	end do
        endif

		call StokesFRsub(stok,rt,rp,rh,rv,rg,rf,rm,rmac)

		if (error_code /= 0) then
			error = error_code
			return
		endif
				 	
! contamos el numero de puntos	
		ntot=0
		do i=1,ntl
        	do j=1,npas(i)
	      		ntot=ntot+1
	    	end do
		end do


! Output Stokes parameters
		stokes(1,:) = dlamda(1:ntot)
		stokes(2,:) = stok(1:ntot)
		stokes(3,:) = stok(ntot+1:2*ntot)
		stokes(4,:) = stok(2*ntot+1:3*ntot)
		stokes(5,:) = stok(3*ntot+1:4*ntot)
        
	end subroutine c_synth


	subroutine c_synthrf(index, nDepth, nLambda, macroturbulence, model, stokes, RFt, RFp, RFh, RFv, RFg, RFf, RFmic, RFmac) bind(c)
	integer(c_int), intent(in) :: index, nDepth, nLambda
	real(c_float), intent(in) :: model(8,ndepth)
	real(c_float), intent(in) :: macroturbulence
	real(c_float), intent(out) :: stokes(5,nLambda)
	real(c_float), intent(out), dimension(4,nLambda,nDepth) :: RFt, RFp, RFh, RFv, RFg, RFf, RFmic
	real(c_float), intent(out), dimension(4,nLambda) :: RFmac

	real*4 stok(kld4)
    real*4 rt(kldt4),rp(kldt4),rh(kldt4),rv(kldt4)
    real*4 rg(kldt4),rf(kldt4),rm(kldt4), rmac(kld4)
    integer ist(4),i,k,ntot, j, l, itau
	character*100 Stokesfilename
	integer*4 mnodos(18), ntau
	real*4 tau(kt),t(kt),pe(kt),pg(kt),z(kt),ro(kt)
	real*4 atmosmodel(kt8), pesostray
	real*4 voffset,xmu

	integer ntl,nlin(kl),npas(kl),nble(kl)
	real*4 dlamda(kld)
	integer ntls,nlins(kl4),npass(kl4)
	real*4 dlamdas(kld4)

    common/OutputStokes/Stokesfilename

    common/Atmosmodel/atmosmodel,ntau !common para StokesFRsub
	common/numeronodos/mnodos         !para StokesFRsub
    common/offset/voffset             !para StokesFRsub
    common/anguloheliocent/xmu        !para StokesFRsub

	common/Malla/ntl,nlin,npas,nble,dlamda  !common para StokesFRsub
    common/Malla4/ntls,nlins,npass,dlamdas  !common para StokesFRsub

		ntl = conf(index)%ntl
		nlin = conf(index)%nlin
		npas = conf(index)%npas
		nble = conf(index)%nble
		dlamda = conf(index)%dlamda
		ntls = conf(index)%ntls
		nlins = conf(index)%nlins
		npass = conf(index)%npass
		dlamdas = conf(index)%dlamdas

	    ntau = nDepth

! offset de velocidad para perturbaciones relativas necesitamos que la velocidad sea siempre positiva        
		voffset=-15.e5    !cm/s
	    xmu=1.            !coseno del angulo heliocentrico	

! Put the model in vectorized form
		atmosmodel(8*ntau+1) = macroturbulence
		atmosmodel(8*ntau+2) = 1.0 ! Filling
		pesostray = 1.0            ! stray
		do i = 1, ntau
			do j = 0, 7
				atmosmodel(i+j*ntau) = model(j+1,i)				
			enddo
			tau(i) = atmosmodel(i)
			t(i) = atmosmodel(i+ntau)
			pe(i) = atmosmodel(i+2*ntau)
		enddo

! pasamos los angulos a radianes
		call taulinea(0,1.,1,0.,atmosmodel,ntau)
	
! definimos los nodos en todos los puntos (excepto para ls presion elctronica)
		do i=1,8                 
        	mnodos(i)=ntau
		end do  
    	mnodos(2)=0  

! Calculate hydrostatic equilibrium if Pe is not known
    	if (minval(model(3,:)) == -1) then

    		call equisubmu(ntau,tau,t,pe,pg,z,ro)
 
        	do i=1,ntau
            	atmosmodel(i+2*ntau)=pe(i)
        	end do
        endif

		call StokesFRsub(stok,rt,rp,rh,rv,rg,rf,rm,rmac)		
		 	
! contamos el numero de puntos	
		ntot=0
		do i=1,ntl
        	do j=1,npas(i)
	      		ntot=ntot+1
	    	end do
		end do

! Output Stokes parameters
		stokes(1,:) = dlamda(1:ntot)
		stokes(2,:) = stok(1:ntot)
		stokes(3,:) = stok(ntot+1:2*ntot)
		stokes(4,:) = stok(2*ntot+1:3*ntot)
		stokes(5,:) = stok(3*ntot+1:4*ntot)

! Output response functions
		do itau = 1, ntau
			RFt(1,:,itau) = rt(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFt(2,:,itau) = rt(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFt(3,:,itau) = rt(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFt(4,:,itau) = rt(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))

			RFp(1,:,itau) = rp(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFp(2,:,itau) = rp(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFp(3,:,itau) = rp(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFp(4,:,itau) = rp(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))

			RFh(1,:,itau) = rh(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFh(2,:,itau) = rh(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFh(3,:,itau) = rh(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFh(4,:,itau) = rh(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))

			RFv(1,:,itau) = rv(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFv(2,:,itau) = rv(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFv(3,:,itau) = rv(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFv(4,:,itau) = rv(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))

			RFg(1,:,itau) = rg(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFg(2,:,itau) = rg(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFg(3,:,itau) = rg(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFg(4,:,itau) = rg(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))

			RFf(1,:,itau) = rf(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFf(2,:,itau) = rf(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFf(3,:,itau) = rf(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFf(4,:,itau) = rf(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))

			RFmic(1,:,itau) = rm(1+4*ntot*(itau-1):ntot+4*ntot*(itau-1))
			RFmic(2,:,itau) = rm(ntot+1+4*ntot*(itau-1):2*ntot+4*ntot*(itau-1))
			RFmic(3,:,itau) = rm(2*ntot+1+4*ntot*(itau-1):3*ntot+4*ntot*(itau-1))
			RFmic(4,:,itau) = rm(3*ntot+1+4*ntot*(itau-1):4*ntot+4*ntot*(itau-1))
			
		enddo

		RFmac(1,:) = rmac(1:ntot)
		RFmac(2,:) = rmac(ntot+1:2*ntot)
		RFmac(3,:) = rmac(2*ntot+1:3*ntot)
		RFmac(4,:) = rmac(3*ntot+1:4*ntot)
        
	end subroutine c_synthrf

end module sirMod
