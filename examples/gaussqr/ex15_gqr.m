% ex15.m
% This example solves a nonlinear BVP in 1D with GQRr collocation
% The problem is the linear critical gradient
%       u_t - (k(u_x)u_x)_x = f   x=[-1,1]
% The diffusivity term is nonlinear and a little confusing
% You can read about it, and all the constants, in my thesis
rbfsetup
global GAUSSQR_PARAMETERS

% True solution, also Dirichlet boundary condition
usol = @(x,t) exp(-t)*(1-x.^2);

% Choose parameters for the simulation
dt = .00001;
T = dt; % Final time (T=dt is one time step)
ep = .01;
alpha = 1;
N = 40;
NN = 100; % Error evaluation points

% Choose the boundary conditions
%   [0 0] - Dirichlet/Dirichlet
%   [1 1] - Neumann/Neumann
%   [0 1] - Dirichlet/Neumann
%   [1 0] - Neumann/Dirichlet
BC = [0 0];

% Choose lsqnonlin solve parameters
opts = optimset('Display','off');

% Set up the spacial discretization
x = pickpoints(-1,1,N,'cheb');
uold = usol(x,0);
xx = pickpoints(-1,1,NN);

% First we must interpolate the initial condition for a guess of
% the coefficients for the time stepping
% This provides us an opportunity to test the choices of ep and alpha
GQRold = gqr_rsolve(x,uold,ep,alpha);
up = gqr_eval(GQRold,x);
errinit = errcompute(up,uold);
fprintf('error of initial condition interpolant : %g\n\n',errinit)

% Need to perform the time stepping
for t=dt:dt:T
    utrue = usol(x,t);
    GQRtrue = gqr_rsolve(x,utrue,ep,alpha);
    up = gqr_eval(GQRtrue,x);
    errtrue = errcompute(up,utrue);
    fprintf('At t=%g, error of interpolant : %g\n',t,errtrue)
    
    % Consider the linear version, with k(u_x) = 1
    [ep,alpha,Marr] = gqr_solveprep(1,x,ep,alpha);
    phi = gqr_phi(Marr,x,ep,alpha);
    phixx = gqr_phi(Marr,x,ep,alpha,2);
    A = phi/dt - phixx;
    A([1,end],:) = phi([1,end],:)/dt;
    
    % Compute the source term (need to encapsulate this)
    S_u_xx = exp(-t)*(-2);
    S_u_t = -exp(-t)*(1-x.^2);
    S_f = S_u_t-S_u_xx;
    
    rhs = S_f + uold/dt;
    rhs([1,end]) = utrue([1,end]); % Apply Dirichlet BC
    
    GQRlin = GQRtrue;
    c = A\rhs;
    GQRlin.coef = c;
    
    up = gqr_eval(GQRlin,x);
    errlin = errcompute(up,utrue);
    linres = ex15_gqr_resBC(GQRlin.coef,GQRlin,x,uold,dt,BC,t);
    fprintf('\t\t\t error of linear : %g\t residual : %g\n',errlin,norm(linres))
    
    GQR = GQRold;
    newcoef = lsqnonlin(@(coef) ex15_gqr_resBC(coef,GQR,x,uold,dt,BC,t),c,[],[],opts);
    GQR.coef = newcoef;
    
    ur = gqr_eval(GQR,x);
    errnln = errcompute(ur,utrue);
    nlnres = ex15_gqr_resBC(newcoef,GQR,x,uold,dt,BC,t);
    fprintf('\t\t\t error of nonlin : %g\t residual : %g\n',errnln,norm(nlnres))
    
    plot(x,abs(utrue-ur))
    pause
end