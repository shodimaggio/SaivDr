function output = fcn_Order1BuildingBlockTypeI( input, mtxU, p, nshift ) %#codegen
% FCN_NSOLTX_SUPEXT_TYPE1
%    
% Requirements: MATLAB R2015b
%
% Copyright (c) 2014-2017, Shogo MURAMATSU
%
% All rights reserved.
%
% Contact address: Shogo MURAMATSU,
%                Faculty of Engineering, Niigata University,
%                8050 2-no-cho Ikarashi, Nishi-ku,
%                Niigata, 950-2181, JAPAN
%
% http://msiplab.eng.niigata-u.ac.jp/
%
persistent h;
if isempty(h)
    h = saivdr.dictionary.nsoltx.mexsrcs.Order1BuildingBlockTypeI();
end
set(h,'HalfNumberOfChannels',p);
output = step(h, input, mtxU, nshift);
end
