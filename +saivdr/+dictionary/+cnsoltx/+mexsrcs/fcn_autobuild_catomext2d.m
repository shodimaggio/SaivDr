function [fcnhandler,flag] = fcn_autobuild_catomext2d(nch)
%FCN_AUTOBUILD_ATOMEXT2D
%
% SVN identifier:
% $Id: fcn_autobuild_atomext2d.m 683 2015-05-29 08:22:13Z sho $
%
% Requirements: MATLAB R2013b
%
% Copyright (c) 2014-2015, Shogo MURAMATSU
%
% All rights reserved.
%
% Contact address: Shogo MURAMATSU,
%                Faculty of Engineering, Niigata University,
%                8050 2-no-cho Ikarashi, Nishi-ku,
%                Niigata, 950-2181, JAPAN
%
% LinedIn: http://www.linkedin.com/pub/shogo-muramatsu/4b/b08/627
%

% global isAutoBuildAtomExt2dLocked
% if isempty(isAutoBuildAtomExt2dLocked)
%     isAutoBuildAtomExt2dLocked = false;
% end

bsfname = 'fcn_CnsoltAtomExtender2d';
mexname = sprintf('%s_%d_mex',bsfname,...
    nch);

ftypemex = exist(mexname, 'file');
if exist('getCurrentTask','file') == 2
    task = getCurrentTask();
else
    task = [];
end
if isempty(task) || task.ID == 1
% if ~isAutoBuildAtomExt2dLocked
%     isAutoBuildAtomExt2dLocked = true;
    if ftypemex ~= 3  && ... % MEX file doesn't exist
            license('checkout','matlab_coder') % Coder is available
        cdir = pwd;
        saivdr_root = getenv('SAIVDR_ROOT');
        cd(saivdr_root)
        packagedir = './+saivdr/+dictionary/+cnsoltx/+mexsrcs';
        fbsfile = exist([packagedir '/' bsfname '.m'],'file');
        
        if fbsfile == 2
            
            outputdir = fullfile(saivdr_root,'mexcodes');
            %
            %maxNCfs = 518400;
            %nPmCoefs = (nch(1)^2 +nch(2)^2)*(sum(ord)/2+1);
            %
            aCoefs   = coder.typeof(complex(double(0)),[nch Inf],[0 1]); %#ok
            aScale   = coder.typeof(uint32(0),[1 2],[0 0]); %#ok
            aPmCoefs = coder.typeof(complex(double(0)),[Inf 1],[1 0]); %#ok 
            cNch = coder.Constant(nch); %#ok
            aOrd = coder.typeof(uint32(0),[1 2],[0 0]); %#ok
            aFpe = coder.typeof(logical(0),[1 1],[0 0]); %#ok
            % build mex
            cfg = coder.config('mex');
            cfg.DynamicMemoryAllocation = 'AllVariableSizeArrays';%'Threshold';%'Off';
            cfg.GenerateReport = true;
            args = '{ aCoefs, aScale, aPmCoefs, cNch, aOrd, aFpe }';
            seval = [ 'codegen -config cfg ' ' -o ' outputdir '/' mexname ' ' ...
                packagedir '/' bsfname '.m -args ' args];
            
            disp(seval)
            eval(seval)
            
        else
            error('SaivDr: Invalid argument')
        end
        
        cd(cdir)
    end
    ftypemex = exist(mexname, 'file');
    %isAutoBuildAtomExt2dLocked = false;
end

if ftypemex == 3 % MEX file exists
    
    fcnhandler = str2func(mexname);
    flag       = true;
    
else 

    fcnhandler = [];
    flag       = false;

end