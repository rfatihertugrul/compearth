%
% function get_gps_dataset.m
%
% This function loads a velocity field for certain points on the sphere.
% The examples in surfacevel2strain are for the socal REASON velocity field
% and for a full set of synthetic velocity fields.
%
% The user can adapt this function such that it returns the following
% output variables:
%   dlon    longitude of observation
%   dlat    latitude of observation
%   vu      velocity, vertical component
%   vs      velocity, south component
%   ve      velocity, east component
%   su      uncertainty (std), vu
%   ss      uncertainty (std), vs
%   se      uncertainty (std), ve
%   ax1     lon-lat bounds for region containing observations
%   slabel  string label for the region
%   stref   reference plate (OPTIONAL)
%
% The plate models are not currently implemented.
% 
% calls platemodel2gps.m, read_gps_3D.m
% called by surfacevel2strain.m
%

function [dlon,dlat,vu,vs,ve,su,ss,se,ax1,slabel,stref] ...
    = get_gps_dataset(dir_data,ropt,dopt,istore,iplate_model)

% GEOGRAPHIC REGION
% slabel        label for the region
% ax1           lon-lat box for the region
% irow          only relevant when dealing with a plate model
switch ropt
    case 1, slabel = 'west_us'; ax1 = [-175 -85 -60 60]; irow = 11;
    case 2, slabel = 'cal'; ax1 = [-126 -113.3 30 43.5]; irow = 11;
    case 3, slabel = 'socal'; ax1 = [-122 -113 30 38]; irow = 11;
    case 4, slabel = 'taiwan'; ax1 = [115 125 18 28]; irow = 17;
    case 5, slabel = 'tibet'; ax1 = [52 104 12 44]; irow = 7;
    case 6, slabel = 'cascadia'; ax1 = [-128 -122 38 52]; irow = 7;
    case 7, slabel = 'asia'; ax1 = [68 117 8 57]; irow = 11;
    case 8, slabel = 'parkfield'; ax1 = [-121.4 -119.8 35.1 36.5]; irow = 11;
    case 9, slabel = 'japan'; ax1 = [128 147 30 46]; irow = 11;
    case 10, slabel = 'wedge'; ax1 = [-175 -85 -60 60]; irow = 11;
end
lonmin = ax1(1); lonmax = ax1(2);
latmin = ax1(3); latmax = ax1(4);

if ~exist('slabel','var')
    ropt, slabel
    error('get_gps_dataset.m: invalid region index ropt');
end

%------------------------------
% DATA SET (REAL OR SYNTHETIC)

if length( find(dopt == [0 1 10:13 20:23 60:63 70:73 80:83]) )==0
    error(' check data options (dopt)');
end
if dopt == 0, istore = 0; end
sdopt = sprintf('d%2.2i', dopt);

if istore == 1   % use specific v-field data (velocities in MM/YR)

    % OBSERVED VELOCITY FIELDS
    if dopt == 1        % NASA REASON dataset (modified in REASON_gps_dat.m)
        filename = [dir_data 'reason_subset_3D.dat'];

    % SYNTHETIC VELOCITY FIELDS
    %   10 -- strike-slip, uniform field, no errors
    %   11 -- strike-slip, uniform field, errors
    %   12 -- strike-slip, irregular field, no errors
    %   13 -- strike-slip, irregular field, errors
    %   20-23 -- rotational
    %   60-63 -- microplate rotation, I
    %   70-73 -- microplate rotation, II
    %   80-83 -- volcanic source (Mogi)
    elseif dopt >= 10
        filename = [dir_data 'syn_vfield_' sdopt '_3D.dat'];
    end
    
    % NOTE: It is simpler to store the velocity field in a format that can
    % be read by read_gps_3D.m
    [dlon,dlat,ve,vn,vu,se,ss,su,ren,reu,rnu,start_date,finish_date,name] = read_gps_3D(filename);
    
    ndata = length(dlon);

    % combine into one array
    data_all = [dlon dlat vu vn ve su ss se];

    % ELIMINATE OBSERVATIONS OUTSIDE THE SPECIFIED REGION
    i_inregion = getsubset(dlon,dlat,ax1);
    data_all = data_all(i_inregion,:);

    % convert to meters (per second)
    data_all(:,[3:8]) = data_all(:,[3:8])*1e-3;

    dlon = data_all(:,1);
    dlat = data_all(:,2);
    vu   = data_all(:,3); vs = -data_all(:,4); ve = data_all(:,5);
    su   = data_all(:,6); ss =  data_all(:,7); se = data_all(:,8);

    % see socal_gps_syn.m to add Gaussian noise to the velocity field
    
    % dummy variable to send back
    stref = 'NA';

else   % not using GPS data, so get plate model velocity field

    error('plate option has not yet been provided');
    
    % generate uniform mesh for PLATE MODEL fields
    numx = 60;
    [dlon,dlat] = gridvec(lonmin,lonmax,numx,latmin,latmax);

    % you may want to constrain datapoints OUTSIDE the 'target region'
    %dfac = 0.5 * (latmax-latmin);
    %[dlon2,dlat2] = gridvec(lonmin-dfac,lonmax+dfac,numx,latmin-dfac,latmax+dfac);
    
    %irow = 11;  % FIXED PLATE

    ifix_mat = [ 1 1 1 2        %  1 AFR
                 2 2 4 6        %  2 ANT
                 3 3 5 7        %  3 ARA
                 4 4 6 8        %  4 AUS
                 5 5 7 13       %  5 CAR
                 6 6 99 15      %  6 COC
                 7 7 8 18       %  7 EUR
                 99 8 9 21      %  8 IND
                 8 9 99 22      %  9 JDF
                 9 10 11 32     % 10 NAZ
                 10 11 11 32    % 11 NAM
                 11 12 13 37    % 12 PAC
                 12 13 14 39    % 13 PHI (PS)
                 13 15 16 46    % 14 SAM
                 99 14 99 42    % 15 SCO
                 99 99 17 48    % (16) SU
                 99 99 18 52    % (17) YA
                 ];
    ifix = ifix_mat(irow, iplate_model);
    opts = {0,1,0};

    % compute velocity field for VECTORS
    [dlon, dlat, ve, vn, iplate_vec, exyz, names, name_labs] ...
        = platemodel2gps(dlon,dlat,iplate_model,ifix,opts);

    % convert to from mm/yr to m/yr
    ve = ve * 1e-3;               % ve = v_phi
    vs = -vn * 1e-3;              % vs = v_theta

    stref = name_labs{ifix};      % fixed plate

    % initialize other vectors
    ndata = length(dlon);
    vu = zeros(ndata,1);
    su = zeros(ndata,1); ss = zeros(ndata,1); se = zeros(ndata,1);
end

if isempty(dlon), error('get_gps_dataset.m: zero observations within specified region'); end

%===================================================================
