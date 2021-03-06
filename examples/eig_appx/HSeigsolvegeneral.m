function PHI = HSeigsolvegeneral(kernel,domain,N,B,M,qdopts,split)
%This function approximates Hilbert-Schmidt eigenvalues. 
%The difference between this method and HSeigsolve is this function using
%quadrature to help us.
%
%function PHI = HSeigsolvegeneral(kernel,domain,N,B,M,qdopts)
%
%Inputs :  N      - number of points in the domain
%          kernel - the kernel you want to use, kernel should look like
%          e.g. @(x,z,j) min(x,z,j)
%          [L U]  - domian of the kernel
%          B      - choice of approximating basis
%          M      - different quadrature method to compute the error
%          epsilon- value of epsilon
%          qdopts - quadrature related options
%          split  - whether split for chebfun(by hand)
%          
%Outputs : PHI - eigenfunction object 
%         
% Should call qdopts = qdoptCHECK(M,qdopts)
%
%qdopts will have different structure for each choice of M
%            qdopts.npts        : The number of points to use for quadrature
%                                 methods(not for quadgk or quadl)
%            qdopts.ptspace     : The distribution of quadrature points
%            qdopts.RelTol      : The real tolerance for quadgk
%            qdopts.AbsTol      : the absolute tolerance for quadgk
%            qdopts.integralTOL : the tolerance for quadl if we don't have
%            quadgk
%
%PHI Object details:
%
%    PHI.N         : Number of basis functions
%    PHI.basisName : Which basis is used for the approximation
%    
%    PHI.eigvals   : The computed HSqd eigenvalues
%    PHI.quad      : The quadrature method that were used to compute
%                    eigenvalue
%    PHI.coefs     : Coefficients for evaluating the eigenfunctions
%                    PHI.coefs(:,k) are for the kth eigenfunction
%    
if nargin <7
    split = 1;
    if nargin < 6
        qdopts.npts = N; % create the qdopts object if inputs don't have one.
    end
end

L = domain(1);
U = domain(2);
if (L >= U)
    error('domain is wrong')
end
quadgkEXISTS = 0;
if exist('quadgk')
    quadgkEXISTS = 1;
    RelTol = 1e-8;
    AbsTol = 1e-12;
    if isfield(qdopts,'RelTol')
        RelTol = qdopts.RelTol;
    end
    if isfield(qdopts,'AbsTol')
        AbsTol = qdopts.AbsTol;
    end
else
    integralTOL = 1e-4;
    if isfield(qdopts,'integralTol')
        integralTOL = qdopts.integralTOL;
    end
end




PHI.N = N; %create object PHI
%pick kernel
K_F = kernel;


%pick basis
switch B
    case 1
        PHI.basisName = 'Standard Polynomial';
        ptspace = 'cheb';
        H_mat = @(x,z,j) x.^(j-1);
        x = pickpoints(L,U,N+2,ptspace);
        x = x(2:end-1);
        j = 1:N;
        z =[];
        Z =[];
        X = repmat(x,1,N);
        J = repmat(j,N,1);

    case 2
        PHI.basisName = 'PP Spline Kernel';
        H_mat = @(x,z,j) min(x,z)-x.*z;
        ptspace = 'even';
        x = pickpoints(L,U,N+2,ptspace);x = x(2:end-1);
        X = repmat(x,1,N);
        z = x';
        Z = repmat(z,N,1);
        j = [];
        J = [];
    case 3
        PHI.basisName = 'Chebyshev Polynomials';
        ptspace = 'cheb';
        H_mat = @(x,z,j) cos((j-1).*acos((2/(U-L))*x-(L+U)/(U-L)));       
        x = pickpoints(L,U,N+2,ptspace);
        x = x(2:end-1);
        j = 1:N;
        z =[];
        Z =[];
        X = repmat(x,1,N);
        J = repmat(j,N,1);
    otherwise
        error('Unacceptable basis=%e',B)
end
%pick quadrature method
  switch M
    case 1
        PHI.quad = 'left hand rule';
        Nqd = N;
        if(isfield(qdopts,'npts'))
            Nqd = qdopts.npts;
            if(isfield(qdopts,'ptspace'))
                qdspace = qdopts.ptspace;
            else
                qdspace = 'even';
            end
            v = pickpoints(0,L,Nqd+2,qdspace);
            v = v(2:end-1);
        else
            v = x;
        end
       
        X = repmat(x,1,Nqd);
        J = repmat(j,Nqd,1);
        V = repmat(v,1,N);
        VT = repmat(v',N,1);  
        v(2:Nqd) = v(2:Nqd)-v(1:Nqd-1);
        W = diag(v);
        K = K_F(X,VT,J);
        H = H_mat(V,Z,J);
        PHI.K = K;
        PHI.H = H;
        [eivec,eival] = eig(K*W);
       
    case 2
        PHI.quad = 'quadgk';
        for l = 1:N
            for i = 1:N
               if isempty(z) 
                    if quadgkEXISTS
                        K(l,i) = quadgk(@(p) H_mat(p,z,i).*K_F(x(l),p,i),L,U,'AbsTol',AbsTol,'RelTol',RelTol);
                    else
                        K(l,i) = quadl(@(p) H_mat(p,z,i).*K_F(x(l),p,i),L,U,integralTOL);
                    end
               else
                   if quadgkEXISTS
                        K(l,i) = quadgk(@(p) H_mat(p,z(i),i).*K_F(x(l),p,i),L,U,'AbsTol',AbsTol,'RelTol',RelTol);
                   else
                        K(l,i) = quadl(@(p) H_mat(p,z(i),i).*K_F(x(l),p,i),L,U,integralTOL);
                   end
               end
            end
        end
        H = H_mat(X,Z,J);
        [eivec,eival] = eig(K,H);
        PHI.K = K;
        PHI.H = H;
    case 3 
        PHI.quad = 'chebufun';
        for l = 1:N
            for i = 1:N
               if isempty(z) 
                           p = chebfun('p');
                         if split ==1  
                               chbf = chebfun(@(p) H_mat(p,z,i).*K_F(x(l),p,i),@(p) H_mat(p,z,i).*K_F(x(l),p,i),[L  x(l) U],'splitting','on');
                             % chbf = chebfun(@(p) H_mat(p,z,i).*(p-x(l).*p),@(p) H_mat(p,z,i).*(x(l)-x(l).*p),[L x(l) U],'splitting','on');
                        
                         else
                            chbf = chebfun(@(p) H_mat(p,z,i).*K_F(x(l),p,i),[L U],'splitting','on');
                         end
                         K(l,i) = sum(chbf);
               
       
               else
                           p = chebfun('p');
                     
                        if B == 2 
                            if (z(i) > x(l))
                                %chbf = chebfun(@(p) (p-x(l).*p).*(p-p.*z(i)),@(p) (x(l)-x(l).*p).*(p-p.*z(i)),@(p) (x(l)-x(l).*p).*(z(i)-p.*z(i)), [L x(l) z(i) U]);
                                chbf = chebfun(@(p) K_F(x(l),p,i).*H_mat(p,z(i),i),@(p) K_F(x(l),p,i).*H_mat(p,z(i),i),@(p) K_F(x(l),p,i).*H_mat(p,z(i),i), [L x(l) z(i) U]);
                            else
                                %chbf = chebfun(@(p) (p-x(l).*p).*(p-p.*z(i)),@(p) (p-x(l).*p).*(z(i)-p.*z(i)),@(p) (x(l)-x(l).*p).*(z(i)-p.*z(i)), [L z(i) x(l) U]);
                                chbf = chebfun(@(p) K_F(x(l),p,i).*H_mat(p,z(i),i),@(p) K_F(x(l),p,i).*H_mat(p,z(i),i),@(p) K_F(x(l),p,i).*H_mat(p,z(i),i), [L z(i) x(l) U]);
                            end
                        else
                            error('somthing error')
                        end
                        K(l,i) = sum(chbf);
                end
            end
        end
        H = H_mat(X,Z,J);
        [eivec,eival] = eig(K,H);
        PHI.K = K;
        PHI.H = H;
    otherwise
        error('Unacceptable quadrature method=%e',M);
    end
 [esort,ix] = sort(diag(eival),'descend');
 eivec = eivec(:,ix);
 eival = eival(ix,ix);
 PHI.eigvals = diag(eival);
 PHI.coefs = eivec;
  











