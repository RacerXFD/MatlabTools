classdef UC
    % This class is for handling values with an associated uncertainty
    %
    % It is designed to be a "stand-in" replacement for numeric data in
    % Matlab that carries an uncertainty value through your operations
    % by overloading basic math operations like addition, subtraction,
    % etc...
    %
    % For example, to create two UC variables, you could do
    %
    %   x = UC(1,3,'x');  % value is 1, uncertainty is 3, name is 'x'
    %   y = UC(10,1,'y'); % value is 10, uncertainty is 1, name is 'y'
    %
    % You can then use x and y as you would normal Matlab variables, so
    %
    %   z = x + y;
    %   w = z^(x+y);
    %
    % would propogate the original uncertainty through to z and w.
    
    % Copyright (c) 2014, Tyler Voskuilen
    % All rights reserved.
    % 
    % Redistribution and use in source and binary forms, with or without 
    % modification, are permitted provided that the following conditions are 
    % met:
    % 
    %     * Redistributions of source code must retain the above copyright 
    %       notice, this list of conditions and the following disclaimer.
    %     * Redistributions in binary form must reproduce the above copyright 
    %       notice, this list of conditions and the following disclaimer in 
    %       the documentation and/or other materials provided with the 
    %       distribution
    %       
    % THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS 
    % IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
    % THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR  
    % PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
    % CONTRIBUTORS BE  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
    % EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
    % PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
    % PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
    % LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
    % NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
    % SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


    %----------------------------------------------------------------------
    properties (SetAccess = protected) %You may not change these
        Name = '';   % Variable name
        Value = 0;   % Value
        Inputs = {}; % Cell array of inputs to this variable
        dydx = [];   % Array of derivatives for each input
        e = [];      % Array of error scalars for each input
    end
    
    properties (Dependent = true) %You may not change these
        Err;    % Value uncertainty (calculated from e and dydx vectors)
    end
    

    %----------------------------------------------------------------------
    % Private static functions
    methods(Static) %, Access = private)
        
        %------------------------------------------------------------------
        function y = UnaryFunction(a,f,dfda)
            Av = reshape({a.Value},size(a));
            Ad = reshape({a.dydx},size(a));
            
            % Error vector and input vector do not change
            Ye = reshape({a.e},size(a));
            Yi = reshape({a.Inputs},size(a));
            
            % Value and derivative vector do change
            Yv = cellfun(f, Av, 'UniformOutput',false);
            Yd = cellfun(@(a,dadx) dfda(a).*dadx, Av, Ad,'UniformOutput',false);
                
            y = UC(Yv,Ye,Yi,Yd);
        end
        
        %------------------------------------------------------------------
        function y = BinaryFunction(a,b,f,dfdx)
            % Extract cell arrays from a and b inputs
            [Av,Ad,Bv,Bd,Yi,Ye] = UC.EqualizeInputs(a,b);
            
            % Chain rule
            Yd = cellfun(dfdx, Av,Ad,Bv,Bd,'UniformOutput',false);
            Yv = cellfun(f, Av,Bv,'UniformOutput',false);
            
            y = UC(Yv,Ye,Yi,Yd);
        end
        
        %------------------------------------------------------------------
        function [Av,Adn,Bv,Bdn,Yi,Ye] = EqualizeInputs(A,B)
            % Extract value, error, and derivative arrays from inputs

            if isa(A,'UC')
                Av = reshape({A.Value},size(A));
                Ae = reshape({A.e},size(A));
                Ad = reshape({A.dydx},size(A));
                Ai = reshape({A.Inputs},size(A));
            else
                Av = num2cell(A);
                Ae = cell(size(A));
                Ad = cell(size(A));
                Ai = cell(size(A));
            end
            
            if isa(B,'UC')
                Bv = reshape({B.Value},size(B));
                Be = reshape({B.e},size(B));
                Bd = reshape({B.dydx},size(B));
                Bi = reshape({B.Inputs},size(B));
            else
                Bv = num2cell(B);
                Be = cell(size(B));
                Bd = cell(size(B));
                Bi = cell(size(B));
            end
            
            % Expand cell arrays to match sizes
            if all(size(A) == 1) && ~all(size(B) == 1) % expand A
                Av = cellfun(@(x) Av{1}, Bv, 'UniformOutput',false);
                Ae = cellfun(@(x) Ae{1}, Bv, 'UniformOutput',false);
                Ad = cellfun(@(x) Ad{1}, Bv, 'UniformOutput',false);
                Ai = cellfun(@(x) Ai{1}, Bv, 'UniformOutput',false);
            elseif all(size(B) == 1) && ~all(size(A) == 1) % expand B
                Bv = cellfun(@(x) Bv{1}, Av, 'UniformOutput',false);
                Be = cellfun(@(x) Be{1}, Av, 'UniformOutput',false);
                Bd = cellfun(@(x) Bd{1}, Av, 'UniformOutput',false);
                Bi = cellfun(@(x) Bi{1}, Av, 'UniformOutput',false);
            end
            
            % Get list of unique inputs for each component
            [Yi,~,ic] = cellfun(@(a,b) unique([a, b],'stable'),Ai,Bi,'UniformOutput',false);

            % Expand e and d vectors
            Adn = cellfun(@(c) zeros(size(c)),Yi,'UniformOutput',false);
            Bdn = cellfun(@(c) zeros(size(c)),Yi,'UniformOutput',false);
            Ye = cellfun(@(c) zeros(size(c)),Yi,'UniformOutput',false);
            for i = 1:numel(Ad)
                Adn{i}(ic{i}(1:numel(Ad{i}))) = Ad{i};
                Bdn{i}(ic{i}(numel(Ad{i})+1:end)) = Bd{i};
                Ye{i}(ic{i}(1:numel(Ae{i}))) = Ae{i};
                Ye{i}(ic{i}(numel(Ae{i})+1:end)) = Be{i};
            end

        end
        
    end

    %----------------------------------------------------------------------
    %Define class methods
    methods
        %------------------------------------------------------------------
        %Constructor function
        function uc = UC(val, err, inputNames, dydx)
            [~,fldr] = fileparts(pwd);
            if strcmpi(fldr,'@UC')
                error('MATLAB:UC',...
                      'Do not work inside the "@UC" folder');
            end
            
            if nargin ~= 0
                if ~iscell(val)
                    val = num2cell(val);
                end
                
                % Set err to 0 if not provided, otherwise convert to cell
                if ~exist('err','var')
                    err = num2cell(zeros(size(val)));
                else
                    if ~iscell(err)
                        err = num2cell(err);
                    end
                end

                %Expand err if it is too small
                if ~isequal(size(val),size(err))
                    if all(size(err) == 1)
                        err = cellfun(@(e) err{1}, val, 'UniformOutput',false);
                    else
                        error('Value and Error must be the same size')
                    end
                end

                %Set name
                if ~exist('inputNames','var')
                    % Generate a random name if no name was specified
                    randName = sprintf('ucvar%05d',round(rand(1,1)*100000));
                    inputNames = cellfun(@(x) {randName},val,'UniformOutput',false);
                    if numel(val) > 1
                        for i = 1:numel(inputNames)
                            inputNames{i} = strcat(inputNames{i},'[',num2str(i),']');
                        end
                    end
                elseif ischar(inputNames)
                    % Assign the input name to all values if the input
                    % was a string
                    inputNames = cellfun(@(x) {inputNames},val,'UniformOutput',false);
                    if numel(val) > 1
                        for i = 1:numel(inputNames)
                            inputNames{i} = strcat(inputNames{i},'[',num2str(i),']');
                        end
                    end
                else
                    nameStr = cell(size(inputNames));
                    for i = 1:numel(inputNames)
                        nameStr{i} = 'f(';
                        for j = 1:length(inputNames{i})-1
                            nameStr{i} = strcat(nameStr{i},inputNames{i}{j},',');
                        end
                        nameStr{i} = strcat(nameStr{i},inputNames{i}{end},')');
                    end
                end

                %Set derivatives to 1 if not provided
                if ~exist('dydx','var')
                    dydx = num2cell(ones(size(val)));
                end

                uc(numel(val)) = UC;
                for i=1:numel(val)
                    uc(i).Value = val{i};
                    uc(i).e = err{i};
                    uc(i).dydx = dydx{i};
                    
                    tmp = val{i}+err{i}; %#ok<NASGU> %make sure they are compatible types
                    
                    if exist('nameStr','var')
                        uc(i).Name = nameStr{i};
                    else
                        uc(i).Name = inputNames{i}{1};
                    end
                    
                    uc(i).Inputs = inputNames{i};
                end
                uc = reshape(uc,size(val));
            end
        end

        
        %------------------------------------------------------------------
        % Operator overloading
        %------------------------------------------------------------------
        function y = plus(A, B)
            % Addition operator
            %  f = a + b
            %  dfdx = dadx + dbdx
            y = UC.BinaryFunction(A,B,...
                                  @(a,b) a+b, ...
                                  @(a,dadx,b,dbdx) dadx+dbdx);
        end
        
        %------------------------------------------------------------------
        function y = minus(A, B)
            % Subtraction operator
            %  f = a - b
            %  dfdx = dadx - dbdx
            y = UC.BinaryFunction(A,B,...
                                  @(a,b) a-b, ...
                                  @(a,dadx,b,dbdx) dadx-dbdx);
        end
        
        %------------------------------------------------------------------
        function y = times(A, B)
            % Multiplcation operator
            %  f = a*b
            %  dfdx = b*dadx + a*dbdx
            y = UC.BinaryFunction(A,B,...
                                  @(a,b) a.*b, ...
                                  @(a,dadx,b,dbdx) dadx.*b + dbdx.*a);
        end
        
        %------------------------------------------------------------------
        function y = rdivide(A, B)            
            % Division operator
            %  f = a/b
            %  dfdx = (b*dadx - a*dbdx)/b^2
            y = UC.BinaryFunction(A,B,...
                    @(a,b) a./b, ...
                    @(a,dadx,b,dbdx) (b.*dadx - a.*dbdx)./b.^2);
        end
        
        %------------------------------------------------------------------
        function y = power(A, B)
            % Power operator
            %  f = a^b
            %  dfdx = b*a^(b-1)*dadx + a^b*log(a)*dbdx
            y = UC.BinaryFunction(A,B,...
                    @(a,b) a.^b, ...
                    @(a,dadx,b,dbdx) b.*a.^(b-1).*dadx+a.^b.*log(a).*dbdx);
        end
       
        %------------------------------------------------------------------
        function bool = lt(A, B)
            % Less than operator
            if ~isa(A,'UC')
                A = UC(A);
            end
            if ~isa(B,'UC')
                B = UC(B);
            end
            bool = ([A.Value] < [B.Value]);
        end
        
        %------------------------------------------------------------------
        function bool = gt(A, B)
            % Greater than operator
            if ~isa(A,'UC')
                A = UC(A);
            end
            if ~isa(B,'UC')
                B = UC(B);
            end
            bool = ([A.Value] > [B.Value]);
        end
        
        %------------------------------------------------------------------
        function neg = uminus(A)
            % Negation operator
            neg = A;
            neg.Value = -neg.Value;
        end
        
        %------------------------------------------------------------------
        function val = double(self)
            % Define conversion to double
            val = [self.Value];
            val = reshape(val,size(self));
        end
        
        %------------------------------------------------------------------
        function pos = uplus(A)
            % Unary + operator
            pos = A;
        end
        
        %------------------------------------------------------------------
        function bool = eq(A, B)
            % Equality operator - compares value only
            if ~isa(A,'UC')
                A = UC(A);
            end
            if ~isa(B,'UC')
                B = UC(B);
            end
            bool = ([A.Value] == [B.Value]);
        end
        
        %------------------------------------------------------------------
        function bool = le(a, b)
            % Less than or equal to operator
            bool = ~(a > b);
        end
        
        %------------------------------------------------------------------
        function bool = ge(a, b)
            % Greater than or equal to operator
            bool = ~(a < b);
        end
        
        %------------------------------------------------------------------
        function bool = ne(a, b)
            % Inequality operator
            bool = ~(a == b);
        end
        
        %------------------------------------------------------------------
        function y = mtimes(A, B)
            % Matrix/vector multiplcation ('*' operator)
            y = A.*B;
        end
        
        %------------------------------------------------------------------
        function y = mrdivide(A, B)
            % Matrix division
            y = A ./ B;
        end
        
        %------------------------------------------------------------------
        function y = mpower(A, B)
            % Matrix power operator
            y = A .^ B;
        end
        
        %------------------------------------------------------------------
        function display(a)
            % Display the value and uncertainty
            disp(num2str(a));
        end
        
        %------------------------------------------------------------------
        function y = abs(x)
            % Absolute value
            y = UC.UnaryFunction(x, @abs, @(v) sign(v));
        end
        
        %------------------------------------------------------------------
        function y = cos(x)
            % Cosine function
            y = UC.UnaryFunction(x, @cos, @sin );
        end
        
        %------------------------------------------------------------------
        function y = sin(x)
            % Sine function
            y = UC.UnaryFunction(x, @sin, @cos );
        end
        
        %------------------------------------------------------------------
        function y = tan(x)
            % Tangent function
            y = UC.UnaryFunction(x, @tan, @(v) sec(v).^2);
        end
        
        %------------------------------------------------------------------
        function y = csc(x)
            % Cosecant function
            y = UC.UnaryFunction(x, @csc, @(v) csc(v).*cot(x));
        end
        
        %------------------------------------------------------------------
        function y = sec(x)
            % Secant function
            y = UC.UnaryFunction(x, @sec, @(v) sec(v).*tan(x));
        end
        
        %------------------------------------------------------------------
        function y = cot(x)
            % Cotangent function
            y = UC.UnaryFunction(x, @cot, @(v) csc(v).^2);
        end
        
        %------------------------------------------------------------------
        function y = atan(x)
            % Inverse tangent function
            y = UC.UnaryFunction(x, @atan, @(v) 1./(1+v.^2));
        end
         
        %------------------------------------------------------------------
        function y = asin(x)
            % Inverse sine function
            y = UC.UnaryFunction(x, @asin, @(v) 1./sqrt(1-v.^2));
        end
        
        %------------------------------------------------------------------
        function y = acos(x)
            % Inverse cosine function
            y = UC.UnaryFunction(x, @acos, @(v) 1./sqrt(1-v.^2));
        end
        
        %------------------------------------------------------------------
        function y = asec(x)
            % Inverse secant function
            y = UC.UnaryFunction(x, @asec, @(v) 1./(v.*sqrt(v.^2-1)));
        end
        
        %------------------------------------------------------------------
        function y = acsc(x)
            % Inverse cosecant function
            y = UC.UnaryFunction(x, @acsc, @(v) 1./(v.*sqrt(v.^2-1)));
        end
        
        %------------------------------------------------------------------
        function y = acot(x)
            % Inverse cotangent function
            y = UC.UnaryFunction(x, @acot, @(v) 1./(1+v.^2));
        end
        
        %------------------------------------------------------------------
        function y = sqrt(x)
            % Square root
            y = UC.UnaryFunction(x, @sqrt, @(v) 0.5./v.^0.5);
        end
        
        %------------------------------------------------------------------
        function y = exp(x)
            % Exponential function 
            y = UC.UnaryFunction(x, @exp, @(v) exp(v));
        end
        
        %------------------------------------------------------------------
        function y = log(x)
            % Natural log function 
            y = UC.UnaryFunction(x, @log, @(v) 1./v);
        end
        
        %------------------------------------------------------------------
        function y = log10(x)
            % Log base 10 function 
            y = UC.UnaryFunction(x, @log10, @(v) 1./(v.*log(10)));
        end
        
        %------------------------------------------------------------------
        function y = log2(x)
            % Log base 2 function 
            y = UC.UnaryFunction(x, @log2, @(v) 1./(v.*log(2)));
        end
        
        %------------------------------------------------------------------
        function y = sum(a)
            % Array sum function (does not exactly mimic sum for matrices)
            y = a(1);
            for i = 2:numel(a)
                y = y + a(i);
            end
        end
        
        %------------------------------------------------------------------
        function y = mean(a)
            % Array mean function (does not exactly mimic mean for matrices)
            y = sum(a)/numel(a);
        end
        
        %------------------------------------------------------------------
        function y = min(x)
            % Array min function (does not exactly mimic min for matrices) 
            y = x([x.Value] == min([x.Value]));
        end
        
        %------------------------------------------------------------------
        function y = max(x)
            % Array max function (does not exactly mimic max for matrices) 
            y = x([x.Value] == max([x.Value]));
        end
        
        %------------------------------------------------------------------
        function str = num2str(a,arg)
            % Generate string of value and uncertainty
            if nargin > 1
                str = [num2str(a(1).Value,arg),' ',char(177),' ',...
                       num2str(a(1).Err,arg)];
                for i = 2:numel(a)
                    str = strcat(str,[', ',num2str(a(i).Value,arg),...
                                      ' ',char(177),' ',...
                                      num2str(a(i).Err,arg)]);
                end
            else
                str = [num2str(a(1).Value),' ',char(177),' ',...
                       num2str(a(1).Err)];
                for i = 2:numel(a)
                    str = strcat(str,[', ',num2str(a(i).Value),...
                                      ' ',char(177),' ',...
                                      num2str(a(i).Err)]);
                end
            end
        end
        
        
        %------------------------------------------------------------------
        function Err = get.Err(self)
            % Return the total uncertainty
            Err = sqrt(sum((self.e.*self.dydx).^2));
        end
        
    end %end methods
end %end class
