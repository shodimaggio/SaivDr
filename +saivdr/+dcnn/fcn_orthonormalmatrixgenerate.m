function matrix = fcn_orthonormalmatrixgenerate(angles,mus,pdAng)
%FCN_ORTHONORMALMATRIXGENERATE
%
% Function realization of
% saivdr.dictionary.utility.OrthonormalMatrixGenerationSystem
% for supporting dlarray (Deep learning array for custom training
% loops)
%
% Requirements: MATLAB R2020a
%
% Copyright (c) 2020, Shogo MURAMATSU
%
% All rights reserved.
%
% Contact address: Shogo MURAMATSU,
%                Faculty of Engineering, Niigata University,
%                8050 2-no-cho Ikarashi, Nishi-ku,
%                Niigata, 950-2181, JAPAN
%
% http://msiplab.eng.niigata-u.ac.jp/

if nargin < 3
    pdAng = 0;
end

if isempty(angles)
    matrix = diag(mus);
else
    nDim_ = (1+sqrt(1+8*length(angles)))/2;
    %matrix = eye(nDim_,'like',angles);
    matrix = zeros(nDim_,'like',angles);
    for idx = 1:nDim_
        matrix(idx,idx) = 1;
    end
    iAng = 1;
    for iTop=1:nDim_-1
        vt = matrix(iTop,:);
        for iBtm=iTop+1:nDim_
            angle = angles(iAng);
            if iAng == pdAng
                angle = angle + pi/2;
            end
            c = cos(angle); %
            s = sin(angle); %
            vb = matrix(iBtm,:);
            %
            u  = s*(vt + vb);
            vt = (c + s)*vt;
            vb = (c - s)*vb;
            vt = vt - u;
            if iAng == pdAng
                matrix = 0*matrix;
            end
            matrix(iBtm,:) = vb + u;
            %
            iAng = iAng + 1;
        end
        matrix(iTop,:) = vt;
    end
    matrix = diag(mus)*matrix;
end
end

