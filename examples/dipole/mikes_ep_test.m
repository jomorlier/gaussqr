%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%           MEG meshfree forward solver for a single sphere model
%                            - Kansa's method -
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Calls on:
%   BallGeometry.m
%   SphereSurfGoldPoints.m
%   DistanceMatrix.m
%   DifferenceMatrix.m
%   gradphiF_dip.m
%   phiF_dip.m
%   HomSpherePotential.m
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Warning: singularities of analytic potential formula for dipole located
% at origin
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
global GAUSSQR_PARAMETERS
if ~isstruct(GAUSSQR_PARAMETERS)
    error('GAUSSQR_PARAMETERS does not exist ... did you forget to call rbfsetup?')
end
GAUSSQR_PARAMETERS.ERROR_STYLE = 3;
GAUSSQR_PARAMETERS.NORM_TYPE = 2;

% Set random number generator to constant
% This is used in choosing which BC points are Dirichlet in the mixed case
rng(0);

% Input data
%--------------------------------------------------------------------------

% Medium data
R = 0.1;                      % Sphere radius [m]
sig = 0.2;                    % Electric conductivity [S/m]
% Sources data
dipmom = 2.7e-12.*[1, 0, 0];  % Dipole moment [Am]
srcpnts = [0, 0, 0.6*R];      % Dipole position [m]
% Magnetic induction field observation points
% obspnts = ; ...
% Parameters for numerical computation
radbasfun = 'imq';     % Radial basis function
Npnts = 300;                % Number of desired interior points
epvec = logspace(0,2,20);  % Vector of epsilon values for study


% What boundary conditions do we consider
BC_choice = 3;          % 1 - neumann, 2 - dirichlet, 3 - mixed
% If we want mixed BC, what is the max (likely) number of dirichlet points
N_dir_suggested = 12;


% RBF definition and derivatives
%--------------------------------------------------------------------------
% rbf     = Radial basis function;
% dxrbf   = component along x of the gradient of the RBF
% dyrbf   = component along y of the gradient of the RBF
% dzrbf   = component along z of the gradient of the RBF
% Lrbf    = Laplacian of the RBF in 3D
[rbf, dxrbf, dyrbf, dzrbf, Lrbf] = pickRBF(radbasfun);


% Collocation matrix and known-terms vector
%--------------------------------------------------------------------------

% Collocation points
[POINTS, NORMALS] = BallGeometry(R, Npnts, 'kansa');
intdata = POINTS.int1;
bdydata = POINTS.bdy11;
N_int = size(intdata,1);
N_bdy = size(bdydata,1);

% Centers
ctrs = [intdata; bdydata];

% Evaluation points
evalpnts = SphereSurfGoldPoints(1000, R);
neval = size(evalpnts,1);
    
% Determine which points are Neumann and which are Dirichlet
%   Notice the use of zeros(0,3), not []
%   To allow for bdydata_neu(:,1) calls later
if BC_choice==1 % Do the standard Neumann BC
    bdydata_neu = bdydata;
    normvecs = NORMALS.n11;
    bdydata_dir = zeros(0,3);
elseif BC_choice==2 % Run a test with Dirichlet BC
    bdydata_neu = zeros(0,3);
    normvecs = zeros(0,3);
    bdydata_dir = bdydata;
else % Consider the new mixed case
    N_dir = min(N_dir_suggested,.5*N_bdy);
    i_dir = randperm(N_bdy,N_dir);
    i_neu = setdiff(1:N_bdy,i_dir);
    
    bdydata_neu = bdydata(i_neu,:);
    normvecs = NORMALS.n11(i_neu,:);
    bdydata_dir = bdydata(i_dir,:);
end

% Find all the necessary distance matrices
DM_intdata = DistanceMatrix(intdata,ctrs);
rhs_int = zeros(size(intdata,1),1);


% Consider the Neumann BC
DM_bdydata_neu = DistanceMatrix(bdydata_neu,ctrs);

% Find all the necessary difference matrices
dx_bdydata_neu = DifferenceMatrix(bdydata_neu(:,1),ctrs(:,1));
dy_bdydata_neu = DifferenceMatrix(bdydata_neu(:,2),ctrs(:,2));
dz_bdydata_neu = DifferenceMatrix(bdydata_neu(:,3),ctrs(:,3));

% Compute known-terms vector (a.k.a. righthand side vector)
gradphi_F = gradphiF_dip(bdydata_neu, srcpnts, dipmom, sig);% Gradient of the 
                                                    % potential at boundary
                                                    % in the unbound case
rhs_bdy_neu = -sum(normvecs.*gradphi_F,2);


% Now we consider the Dirichlet BC component
DM_bdydata_dir = DistanceMatrix(bdydata_dir,ctrs);
BCM_dir = rbf(ep,DM_bdydata_dir);

% Compute the true solution to be used as Dirichlet BC
phi_F_bdy_dir = phiF_dip(bdydata_dir,srcpnts,dipmom,sig);
phi_bdy_dir = HomSpherePotential(R, sig, srcpnts, dipmom, bdydata_dir);
rhs_bdy_dir = phi_bdy_dir - phi_F_bdy_dir;


% Compose full rhs
rhs = [rhs_int;rhs_bdy_neu;rhs_bdy_dir];


% This is the analytic component of the computed solution
phi_F = phiF_dip(evalpnts,srcpnts,dipmom,sig);
%  Analytic solution for the potential
phi_an = HomSpherePotential(R, sig, srcpnts, dipmom, evalpnts);
% Evaluation matrix for computing the error
DM_eval = DistanceMatrix(evalpnts, ctrs);


errvec = [];
condvec = [];
k = 1;
for ep=epvec
    fprintf('ep=%g\n',ep)
    
    % Compute blocks for collocation matrix using this ep
    % Interior points
    LCM = Lrbf(ep,DM_intdata);
    % Neumann boundary points
    A = bsxfun(@times,normvecs(:,1),dxrbf(ep,DM_bdydata_neu,dx_bdydata_neu));
    B = bsxfun(@times,normvecs(:,2),dyrbf(ep,DM_bdydata_neu,dy_bdydata_neu));
    C = bsxfun(@times,normvecs(:,3),dzrbf(ep,DM_bdydata_neu,dz_bdydata_neu));
    BCM_neu = A + B + C;
    % Dirichlet boundary points
    BCM_dir = rbf(ep,DM_bdydata_dir);
    % Evaluation matrix
    EM = rbf(ep, DM_eval);
    
    % Collocation matrix in same order as rhs
    CM = [LCM; BCM_neu; BCM_dir];
    % Coefficients for evaluation
    [coefs,recip_cond] = linsolve(CM,rhs);
    
    % Potential at evalpnts in the source free case
    phi0 = EM * coefs;
    % Potential at evalpnts (superposition of effects)
    phi = phi0 + phi_F;
    
    % Comparison and maximum errors
    %--------------------------------------------------------------------------
    % Potential
    errvec(k) = errcompute(phi,phi_an);
    condvec(k) = 1/recip_cond;
    k = k + 1;
end

clf reset

switch GAUSSQR_PARAMETERS.ERROR_STYLE
    case 1
        errstr = 'Pointwise Rel Err';
    case 2
        errstr = 'Absolute Error';
    case 3
        errstr = 'Relative Error';
    case 4
        errstr = 'RMS Relative Error';
end
switch BC_choice
    case 1
        bcstr = 'Neumann BC';
    case 2
        bcstr = 'Dirichlet BC';
    case 3
        bcstr = sprintf('Mixed BC, N_{dir} = %d',N_dir);
end

condcolor = 'm';
errcolor = 'k';

[AX,H1,H2] = plotyy(epvec,errvec,epvec,condvec,@loglog);
xlabel('\epsilon')
set(get(AX(1),'Ylabel'),'String',errstr)
set(AX(1),'Ycolor',errcolor)
set(get(AX(2),'Ylabel'),'String','Matrix Condition','Color',condcolor)
set(AX(2),'Ycolor',condcolor)
set(H1,'LineWidth',3,'Color',errcolor)
set(H2,'LineWidth',3,'Color',condcolor)
[min_err,min_ep_ind] = min(errvec);
fprintf('\tbest_err = %g\n\tbest_ep = %g\n\tN = %d\n',min_err,epvec(min_ep_ind),length(ctrs));