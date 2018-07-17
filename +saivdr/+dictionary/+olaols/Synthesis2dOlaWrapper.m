classdef Synthesis2dOlaWrapper < saivdr.dictionary.AbstSynthesisSystem
    %SYNTHESIS2DOLAWRAPPER OLA wrapper for 2-D synthesis system
    %
    % Reference:
    %   Shogo Muramatsu and Hitoshi Kiya,
    %   ''Parallel Processing Techniques for Multidimensional Sampling
    %   Lattice Alteration Based on Overlap-Add and Overlap-Save Methods,'' 
    %   IEICE Trans. on Fundamentals, Vol.E78-A, No.8, pp.939-943, Aug. 1995
    %
    % Requirements: MATLAB R2018a
    %
    % Copyright (c) 2018, Shogo MURAMATSU
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
    
    properties (Nontunable)
        Synthesizer
        BoundaryOperation
        PadSize = [0 0]
    end
    
    properties (Logical)
        UseParallel = false
    end
    
    properties (Nontunable, PositiveInteger)
        VerticalSplitFactor = 1
        HorizontalSplitFactor = 1
    end
    
    properties (Hidden, Transient)
        BoundaryOperationSet = ...
            matlab.system.StringSet({'Circular'});
    end
    
    properties (Access = private, Nontunable)
        refSize
        refSubSize
        refSynthesizer
    end
    
    methods
        
        % Constractor
        function obj = Synthesis2dOlaWrapper(varargin)
            setProperties(obj,nargin,varargin{:})
            if ~isempty(obj.Synthesizer)
                obj.BoundaryOperation = obj.Synthesizer.BoundaryOperation;
            end
        end
        %{
        function setFrameBound(obj,frameBound)
            obj.FrameBound = frameBound;
        end
        %}
    end
    
    methods (Access = protected)
        
        %{
        function flag = isInactivePropertyImpl(obj,propertyName)
            if strcmp(propertyName,'UseGpu')
                flag = strcmp(obj.FilterDomain,'Frequeny');
            else
                flag = false;
            end
        end        
        %}
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@saivdr.dictionary.AbstSynthesisSystem(obj);
            s.Synthesizer = matlab.System.saveObject(obj.Synthesizer);
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            obj.Synthesizer = matlab.System.loadObject(s.Synthesizer);
            loadObjectImpl@saivdr.dictionary.AbstSynthesisSystem(obj,s,wasLocked);
        end

        function setupImpl(obj,coefs,scales)
            obj.Synthesizer.release();
            obj.refSynthesizer = obj.Synthesizer.clone();
            recImg = step(obj.refSynthesizer,coefs,scales);
            obj.refSize = size(recImg);            
            obj.refSubSize = obj.refSize*...
                diag(1./[obj.VerticalSplitFactor,obj.HorizontalSplitFactor]);
            % Evaluate
            % Check if scales are divisible by split factors
            exceptionId = 'SaivDr:IllegalSplitFactorException';            
            message = 'Split factor must be a divisor of array size.';
            if sum(mod(obj.refSubSize,1)) ~= 0
                throw(MException(exceptionId,message))                
            end
            % Check identity
            exceptionId = 'SaivDr:ReconstructionFailureException';            
            message = 'Failure occurs in reconstruction. Please check the split and padding size.';
            diffImg = recImg - stepImpl(obj,coefs,scales);
            if norm(diffImg(:))/numel(diffImg) > 1e-6
                throw(MException(exceptionId,message))
            end
            % Delete reference synthesizer
            obj.refSynthesizer.delete()
        end
        
        function recImg = stepImpl(obj,coefs,scales)
            % 1. Split
            subCoefArrays = split_(obj,coefs,scales);
            % 2. Zero Padding
            subCoefArrays = padding_(obj,subCoefArrays); 
            [subCoefs,subScales] = convert_(obj,subCoefArrays);
            % 3. Synthesize
            nSplit = length(subCoefs);
            subRecImg = cell(nSplit,1);
            %
            synthesizer_ = cell(nSplit,1);            
            if obj.UseParallel
                nWorkers = nSplit;
                for iSplit=1:nSplit
                   synthesizer_{iSplit} = clone(obj.Synthesizer);
                end            
            else
                nWorkers = 0;
                for iSplit=1:nSplit
                   synthesizer_{iSplit} = obj.Synthesizer;
                end                            
            end
            parfor (iSplit=1:nSplit,nWorkers)
               subCoefs_ = subCoefs{iSplit};
               subRecImg{iSplit} = step(synthesizer_{iSplit},subCoefs_,subScales);            
            end
            % 4. Overlap add (Circular)
            recImg = circular_ola_(obj,subRecImg);
        end
        
    end
    
    methods(Access = private)

        function recImg = circular_ola_(obj,subRecImg)
            import saivdr.dictionary.utility.Direction
            step = obj.refSubSize;
            overlap = size(subRecImg{1})-step;
            recImg = zeros(obj.refSize+overlap);
            % Overlap add
            iSplit = 0;
            tIdxHor = 0;
            for iHorSplit = 1:obj.HorizontalSplitFactor
                sIdxHor = tIdxHor + 1;
                tIdxHor= sIdxHor + step(Direction.HORIZONTAL) - 1;
                eIdxHor = tIdxHor + overlap(Direction.HORIZONTAL);
                tIdxVer = 0;
                for iVerSplit = 1:obj.VerticalSplitFactor
                    iSplit = iSplit + 1;
                    sIdxVer = tIdxVer + 1;
                    tIdxVer = sIdxVer + step(Direction.VERTICAL) - 1;
                    eIdxVer = tIdxVer + overlap(Direction.VERTICAL);
                    recImg(sIdxVer:eIdxVer,sIdxHor:eIdxHor) = ...
                        recImg(sIdxVer:eIdxVer,sIdxHor:eIdxHor) + ...
                        subRecImg{iSplit};
                end
            end
            % Folding
            recImg(1:overlap(Direction.VERTICAL),:) = ...
                recImg(1:overlap(Direction.VERTICAL),:) + ...
                recImg(end-overlap(Direction.VERTICAL)+1:end,:);
            recImg(:,1:overlap(Direction.HORIZONTAL)) = ...
                recImg(:,1:overlap(Direction.HORIZONTAL)) + ...
                recImg(:,end-overlap(Direction.HORIZONTAL)+1:end);
            % Cropping & circular shift
            recImg = circshift(imcrop(recImg,[1 1 fliplr(obj.refSize-1)]),...
                -overlap/2);
        end
        
        function [subCoefs,subScales] = convert_(~,subCoefArrays)
            nSplit = size(subCoefArrays,1);
            nChs = size(subCoefArrays,2);
            subScales = zeros(nChs,2);
            subCoefs = cell(nSplit,1);
            for iSplit = 1:nSplit
                tmpCoefs = [];
                for iCh = 1:nChs
                    tmpArray = subCoefArrays{iSplit,iCh};
                    if iSplit == 1
                        subScales(iCh,:) = size(tmpArray);
                    end
                    tmpCoefs = [ tmpCoefs tmpArray(:).' ];
                end
                subCoefs{iSplit} = tmpCoefs;
            end
        end
        
        function subCoefArrays = padding_(obj,subCoefArrays)
            nSplit = size(subCoefArrays,1);
            nChs = size(subCoefArrays,2);
            for iSplit = 1:nSplit
                for iCh = 1:nChs
                    subCoefArrays{iSplit,iCh} = ...
                        padarray(subCoefArrays{iSplit,iCh},...
                        obj.PadSize,0,'both');
                end
            end
        end
        
        function subCoefArrays = split_(obj,coefs,scales)
            nSplit = obj.VerticalSplitFactor*obj.HorizontalSplitFactor;
            % # of channels
            nChs = size(scales,1);
            subScales = scales*diag(...
                [1/obj.VerticalSplitFactor, 1/obj.HorizontalSplitFactor]);
            subCoefArrays = cell(nSplit,nChs);
            %
            eIdx = 0;
            for iCh = 1:nChs
                sIdx = eIdx + 1;
                eIdx = sIdx + prod(scales(iCh,:)) - 1;                
                nRows = scales(iCh,1);
                nCols = scales(iCh,2);                
                coefArrays = reshape(coefs(sIdx:eIdx),[nRows nCols]);                
                %
                nSubRows = subScales(iCh,1);
                nSubCols = subScales(iCh,2);
                iSplit = 0;
                for iHorSplit = 1:obj.HorizontalSplitFactor
                    sColIdx = (iHorSplit-1)*nSubCols + 1;
                    eColIdx = iHorSplit*nSubCols;                    
                    for iVerSplit = 1:obj.VerticalSplitFactor
                        iSplit = iSplit + 1;
                        sRowIdx = (iVerSplit-1)*nSubRows + 1;
                        eRowIdx = iVerSplit*nSubRows;                    
                        subCoefArrays{iSplit,iCh} = ...
                            coefArrays(sRowIdx:eRowIdx,sColIdx:eColIdx);
                    end
                end
            end
        end
    end
end