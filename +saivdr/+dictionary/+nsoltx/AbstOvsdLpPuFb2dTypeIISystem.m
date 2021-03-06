classdef AbstOvsdLpPuFb2dTypeIISystem < ...
        saivdr.dictionary.nsoltx.AbstOvsdLpPuFb2dSystem %#codegen
    %AbstOvsdLpPuFb2dTypeIISystem Abstract class 2-D Type-II OLPPUFB
    %
    % Requirements: MATLAB R2015b
    %
    % Copyright (c) 2014-2020, Shogo MURAMATSU
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
    
    properties (Access = protected)
        matrixE0
        mexFcn
    end

    properties (Access = protected,PositiveInteger)
        nStages
    end

    methods (Access = protected, Static = true, Abstract = true)
        value = getDefaultPolyPhaseOrder_()
    end        
    
    methods
        function obj = AbstOvsdLpPuFb2dTypeIISystem(varargin)
            obj = obj@saivdr.dictionary.nsoltx.AbstOvsdLpPuFb2dSystem(...
                varargin{:});
            updateProperties_(obj);
            updateAngles_(obj);
            updateMus_(obj);
        end
    end
    
    methods (Access = protected)
        
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@saivdr.dictionary.nsoltx.AbstOvsdLpPuFb2dSystem(obj);
            s.nStages  = obj.nStages;
            s.matrixE0 = obj.matrixE0;
            s.mexFcn   = obj.mexFcn;
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            obj.nStages  = s.nStages;
            obj.matrixE0 = s.matrixE0;
            loadObjectImpl@saivdr.dictionary.nsoltx.AbstOvsdLpPuFb2dSystem(obj,s,wasLocked);
            %
            if ~isempty(s.mexFcn)
                if exist(func2str(s.mexFcn),'file') == 3
                    obj.mexFcn  = s.mexFcn;
                else
                    import saivdr.dictionary.nsoltx.mexsrcs.fcn_Order2BuildingBlockTypeII
                    obj.mexFcn = @fcn_Order2BuildingBlockTypeII;
                    obj.mexFlag = false;
                end
            end
            %
            obj.ParameterMatrixSet.release()
        end
        
        function resetImpl(obj)
            resetImpl@saivdr.dictionary.nsoltx.AbstOvsdLpPuFb2dSystem(obj);
        end
        
        function setupImpl(obj,varargin)
            % Prepare MEX function
            if exist('fcn_Order2BuildingBlockTypeII_mex','file')==3
                obj.mexFcn = @fcn_Order2BuildingBlockTypeII_mex;
                obj.mexFlag = true;
            else
                import saivdr.dictionary.nsoltx.mexsrcs.fcn_Order2BuildingBlockTypeII
                obj.mexFcn = @fcn_Order2BuildingBlockTypeII;
                obj.mexFlag = false;
            end
        end
        
        function updateProperties_(obj)
            import saivdr.dictionary.nsoltx.ChannelGroup
            import saivdr.dictionary.utility.Direction
            import saivdr.dictionary.utility.ParameterMatrixContainer
            
            % Check DecimationFactor
            if length(obj.DecimationFactor) > 2
                error('Dimension of DecimationFactor must be less than or equal to two.');
            end
            nHalfDecs = prod(obj.DecimationFactor)/2;
            
            % Check PolyPhaseOrder
            if isempty(obj.PolyPhaseOrder)
                obj.PolyPhaseOrder = obj.getDefaultPolyPhaseOrder_();
            end            
            if length(obj.PolyPhaseOrder) > 2
                error('Dimension of PolyPhaseOrder must be less than or equal to two.');
            end
            ordX = obj.PolyPhaseOrder(Direction.HORIZONTAL);
            ordY = obj.PolyPhaseOrder(Direction.VERTICAL);
            if mod(ordX,2)~=0 || mod(ordY,2)~=0
                error('Polyphase orders must be even.');
            end
            obj.nStages = uint32(1+double(ordX)/2+double(ordY)/2);
            obj.matrixE0 = getMatrixE0_(obj);
            
            % Check NumberOfChannels
            if length(obj.NumberOfChannels) > 2
                error('Dimension of NumberOfChannels must be less than or equal to two.');
            end
            if isempty(obj.NumberOfChannels)
                obj.NumberOfChannels = [ floor(nHalfDecs+1) floor(nHalfDecs) ];
            elseif length(obj.NumberOfChannels) == 1
                if mod(obj.NumberOfChannels,2) == 0
                    id = 'SaivDr:IllegalArgumentException';
                    msg = '#Channels must be odd.';
                    me = MException(id, msg);
                    throw(me);
                else
                    obj.NumberOfChannels = ...
                        [ ceil(double(obj.NumberOfChannels)/2) ...
                        floor(double(obj.NumberOfChannels)/2) ];
                end
           %{
            elseif obj.NumberOfChannels(ChannelGroup.UPPER) <= ...
                    obj.NumberOfChannels(ChannelGroup.LOWER)
                id = 'SaivDr:IllegalArgumentException';
                msg = 'ps must be greater than pa. (not yet supported)';
                me = MException(id, msg);
                throw(me);
            %}
            elseif (obj.NumberOfChannels(ChannelGroup.UPPER) < ceil(nHalfDecs)) ||...
                    (obj.NumberOfChannels(ChannelGroup.LOWER) < floor(nHalfDecs))
                id = 'SaivDr:IllegalArgumentException';
                msg = 'Both of ps and pa must be greater than a half of #Decs.';
                me = MException(id, msg);
                throw(me);                   
            end
            
            % Prepare ParameterMatrixSet
            paramMtxSizeTab = repmat(...
                [ obj.NumberOfChannels(ChannelGroup.UPPER) ;
                obj.NumberOfChannels(ChannelGroup.LOWER) ],...
                obj.nStages,2);
            obj.ParameterMatrixSet = ParameterMatrixContainer(...
                'MatrixSizeTable',paramMtxSizeTab);                       
        end
        
        function updateAngles_(obj)
            import saivdr.dictionary.nsoltx.ChannelGroup
            nAngsPerStg = zeros(2,1);
            %
            nAngsPerStg(ChannelGroup.UPPER) = ...
                obj.NumberOfChannels(ChannelGroup.UPPER) ...
                *double(obj.NumberOfChannels(ChannelGroup.UPPER)-1)/2;
            nAngsPerStg(ChannelGroup.LOWER) = ...
                obj.NumberOfChannels(ChannelGroup.LOWER) ...
                *double(obj.NumberOfChannels(ChannelGroup.LOWER)-1)/2;
            sizeOfAngles = [sum(nAngsPerStg) obj.nStages];
            %
            
            if isscalar(obj.Angles) && obj.Angles == 0
                obj.Angles = zeros(sizeOfAngles);
            end
            coder.extrinsic('sprintf')
            if size(obj.Angles,1) ~= sizeOfAngles(1) || ...
                    size(obj.Angles,2) ~= sizeOfAngles(2)
                id = 'SaivDr:IllegalArgumentException';
                msg = sprintf(...
                    'Size of angles must be [ %d %d ]',...
                    sizeOfAngles(1), sizeOfAngles(2));
                me = MException(id, msg);
                throw(me);
            end
        end
        
        function updateMus_(obj)
            import saivdr.dictionary.nsoltx.ChannelGroup
            %
            sizeOfMus = [ sum(obj.NumberOfChannels) obj.nStages ];
            %
            nChL = obj.NumberOfChannels(ChannelGroup.LOWER);
            nChU = obj.NumberOfChannels(ChannelGroup.UPPER);
            if isscalar(obj.Mus) && obj.Mus == 1
                if nChU > nChL
                    obj.Mus = [
                        ones(nChU, obj.nStages);
                        -ones(nChL, obj.nStages) ];
                else
                    obj.Mus = [
                        -ones(nChU, obj.nStages);
                        ones(nChL, obj.nStages) ];                    
                end
                if mod(obj.nStages,2) == 1
                    obj.Mus(:,1) = ones(size(obj.Mus,1),1);
                end
            end
            coder.extrinsic('sprintf')
            if size(obj.Mus,1) ~= sizeOfMus(1) || ...
                    size(obj.Mus,2) ~= sizeOfMus(2)
                id = 'SaivDr:IllegalArgumentException';
                msg = sprintf(...
                    'Size of mus must be [ %d %d ]',...
                    sizeOfMus(1), sizeOfMus(2));
                me = MException(id, msg);
                throw(me);
            end
        end
        
        function value = getAnalysisFilterBank_(obj)
            import saivdr.dictionary.utility.Direction
            import saivdr.dictionary.nsoltx.ChannelGroup
            import saivdr.dictionary.nsoltx.AbstOvsdLpPuFb2dTypeIISystem
            import saivdr.dictionary.nsoltx.mexsrcs.*
            
            %
            nChs = obj.NumberOfChannels;
            dec  = obj.DecimationFactor;
            decX = dec(Direction.HORIZONTAL);
            decY = dec(Direction.VERTICAL);
            nHalfDecs = prod(dec)/2;
            ordX = obj.PolyPhaseOrder(Direction.HORIZONTAL);
            ordY = obj.PolyPhaseOrder(Direction.VERTICAL);
            pmMtxSt_ = obj.ParameterMatrixSet;
            mexFcn_  = obj.mexFcn;
            %
            E0 = obj.matrixE0;
            %
            cM_2 = ceil(nHalfDecs);
            W = step(pmMtxSt_,[],uint32(1))*[ eye(cM_2) ;
                zeros(nChs(ChannelGroup.UPPER)-cM_2,cM_2)];
            fM_2 = floor(nHalfDecs);
            U = step(pmMtxSt_,[],uint32(2))*[ eye(fM_2);
                zeros(nChs(ChannelGroup.LOWER)-fM_2,fM_2) ];
            R = blkdiag(W,U);
            E = R*E0;
            iParamMtx = uint32(3);
            
            % Horizontal extention
            lenY = decY;
            lenX = decX;
            nShift = int32(lenY*lenX);
            for iOrdX = 1:uint32(double(ordX)/2)
                W = step(pmMtxSt_,[],iParamMtx);
                U = step(pmMtxSt_,[],iParamMtx+1);
                E = mexFcn_(E, W, U, nChs(1), nChs(2), nShift);
                iParamMtx = iParamMtx+2;
            end
           lenX = decX*(ordX+1);
                
            % Vertical extention
            if ordY > 0
                E = permuteCoefs_(obj,E,lenY);
                nShift = int32(lenX*lenY);
                for iOrdY = 1:uint32(double(ordY)/2)
                    W = step(pmMtxSt_,[],iParamMtx);
                    U = step(pmMtxSt_,[],iParamMtx+1);
                    E = mexFcn_(E, W, U, nChs(1), nChs(2), nShift);
                    iParamMtx = iParamMtx+2;
                end
                lenY = decY*(ordY+1);                
                E = ipermuteCoefs_(obj,E,lenY);
            end
            %
            nSubbands = size(E,1);
            value = zeros(lenY,lenX,nSubbands);
            for iSubband = 1:nSubbands
                value(:,:,iSubband) = reshape(E(iSubband,:),lenY,lenX);
            end

        end      
        
        
    end
    
end

