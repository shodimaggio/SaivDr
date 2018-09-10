classdef (Abstract) AbstIterativeMethodSystem < matlab.System
    %ABSTITERATIVERESTORATIONSYSTEM Abstract class for iterative methods
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
    
    properties (Constant)
        FORWARD = 1
        ADJOINT = 2
    end
    
    properties (Nontunable)
        Lambda = 0       % Regulalization Parameter
        %
        MeasureProcess   % Measurment process P
        Dictionary       % Set of synthesis and analysis dictionary {D, D'}
        GaussianDenoiser % Set of Gaussian denoisers {G_R(),...}
        %
        Observation      % Observation y
        %
        Gamma  = 0       % Stepsize parameter(s)
        %
        DataType = 'Image'
        SplitFactor = []
        PadSize     = []
    end
    
    properties (Hidden, Transient)
        DataTypeSet = ...
            matlab.system.StringSet({'Image' 'Volumetric Data'});
    end    

    properties (GetAccess = public, SetAccess = protected)
        Result
        LambdaOriginal
    end
    
    properties(Nontunable, Access = protected)
        AdjointProcess
        ParallelProcess
    end    

    properties(Nontunable, Logical)
        IsIntegrityTest = true
        IsLambdaCompensation = false
        UseParallel = false
        UseGpu = false
    end

    properties(Nontunable,Logical, Hidden)
        Debug = false
    end

    properties(DiscreteState)
        Iteration
    end
    
    methods
        function obj = AbstIterativeMethodSystem(varargin)
            setProperties(obj,nargin,varargin{:})
            if isempty(obj.PadSize)
                if strcmp(obj.DataType,'Volumetric Data')
                    obj.PadSize = zeros(1,3);
                else
                    obj.PadSize = zeros(1,2);
                end
            end
        end
    end
    
    methods (Access = protected)
        
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@matlab.System(obj);
            %s.Var = obj.Var;
            %s.Obj = matlab.System.saveObject(obj.Obj);
            s.AdjointProcess = matlab.System.saveObject(obj.AdjointProcess);
            s.ParallelProcess = matlab.System.saveObject(obj.ParallelProcess);            
            if isLocked(obj)
                s.Iteration = obj.Iteration;
            end
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            if wasLocked
                obj.Iteration = s.Iteration;
            end
            obj.AdjointProcess = matlab.System.loadObject(s.AdjointProcess);            
            obj.ParallelProcess = matlab.System.loadObject(s.ParallelProcess);              
            %obj.Obj = matlab.System.loadObject(s.Obj);
            %obj.Var = s.Var;
            loadObjectImpl@matlab.System(obj,s,wasLocked);
        end
        
        function setupImpl(obj)
            obj.LambdaOriginal = obj.Lambda; 
            if obj.IsLambdaCompensation
                sizeM = numel(obj.Observation); % Data size of measurement 
                src   = msrProc.step(vObs,'Adjoint');
                coefs = adjDic.step(src); % Data size of coefficients
                sizeL = numel(coefs);
                obj.Lambda = obj.LambdaOriginal*(sizeM^2/sizeL);
            end
        end
        
        function stepImpl(obj)
            obj.Iteration = obj.Iteration + 1;
        end

        function resetImpl(obj)
            obj.Iteration = 0;
        end
        
    end
    
    methods (Static)

        function z = rmse(x,y)
            z = norm(x(:)-y(:),2)/sqrt(numel(x));
        end
        
    end
    
end

