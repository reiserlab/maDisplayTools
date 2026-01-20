classdef LEDController < handle
    properties
        serialPort
        docheckstatus 
        dispstatus;
    end
    
    methods
        function obj = LEDController(COMPort)
            obj.serialPort = serialport(COMPort, 115200);
            configureTerminator(obj.serialPort,"CR");
            obj.docheckstatus = true;
            obj.dispstatus = 0;
            try
                fopen(obj.serialPort);
            catch ME
                display(ME.message);
                obj.serialPort = 0;
            end
        end
        
        %%functions to set LED's power
        function setIRLEDPower(obj,power)
            if  ~(obj.serialPort == 0)
                Ir_int_val = round(power);
                %send command to controller
                fprintf(obj.serialPort, ['IR ',num2str(Ir_int_val)]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        
        function setRedLEDPower(obj,varargin)
            if  ~(obj.serialPort == 0)
                nargin
                if nargin == 2 
                    power = round(varargin{1});                    
                    %send command to controller
                    fprintf(obj.serialPort, ['RED ',num2str(power)]);
                elseif nargin == 3
                    power = round(varargin{1}); 
                    panelNum = varargin{2};
                    fprintf(obj.serialPort, ['RED ',num2str(power),' ',num2str(panelNum)]);
                elseif nargin == 4
                    power = round(varargin{1}); 
                    panelNum = varargin{2};
                    pattern = varargin{3};
                    if power>0
                        fprintf(obj.serialPort, ['RED ',num2str(power), ' ',num2str(panelNum),' ', pattern]);
                    end
                end              
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function setGreenLEDPower(obj,varargin)
            if  ~(obj.serialPort == 0)
                if nargin == 2 
                    power = round(varargin{1});                    
                    %send command to controller
                    fprintf(obj.serialPort, ['GRN ',num2str(power)]);
                elseif nargin == 3
                    power = round(varargin{1}); 
                    panelNum = varargin{2};
                    fprintf(obj.serialPort, ['GRN ',num2str(power),' ',num2str(panelNum)]);
                elseif nargin == 4
                    power = round(varargin{1}); 
                    panelNum = varargin{2};
                    pattern = varargin{3};
                    if power>0
                        fprintf(obj.serialPort, ['GRN ',num2str(power), ' ',num2str(panelNum),' ', pattern]);
                    end
                end              
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); en
            end
        end
        
        function setBlueLEDPower(obj,varargin)
            if  ~(obj.serialPort == 0)
                if nargin == 2 
                    power = round(varargin{1});                    
                    %send command to controller
                    fprintf(obj.serialPort, ['BLU ',num2str(power)]);
                elseif nargin == 3
                    power = round(varargin{1}); 
                    panelNum = varargin{2};
                    fprintf(obj.serialPort, ['BLU ',num2str(power),' ',num2str(panelNum)]);
                elseif nargin == 4
                    power = round(varargin{1}); 
                    panelNum = varargin{2};
                    pattern = varargin{3};
                    if power>0
                        fprintf(obj.serialPort, ['BLU ',num2str(power), ' ',num2str(panelNum),' ', pattern]);
                    end
                end              
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        
        function setVisibleBacklightsOff(obj)
            setRedLEDPower(obj,0);
            setGreenLEDPower(obj,0);
            setBlueLEDPower(obj,0);
        end
        
        function setIrBacklightsOff(obj)
            setIRLEDPower(obj,0);
        end
        
        %% functions to set pulse
        
        function setPulseParam(obj,param)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['PULSE ', num2str(param.pulse_width),' ',num2str(param.pulse_period),' ',num2str(param.number_of_pulses), ' ', ...
                    num2str(param.pulse_train_interval),' ',num2str(param.LED_delay),' ',num2str(param.iteration),' ',param.color]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function startPulse(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'RUN');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function stopPulse(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'STOP');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        %% functions to turn on/off LEDs
        function turnOnLED(obj)
            if  ~(obj.serialPort == 0)
                % The first 0 means all panels, the second 0 means all
                % quadrants
                fprintf(obj.serialPort, 'ON 0,0');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function turnOffLED(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'OFF');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        %% functions to control marker
        function blinkMarker(obj,blinkT)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['blink ',num2str(blinkT),' red']);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        %% Function to control marker LED off/ on

        function markerLEDON(obj,color)
             if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['Marker ', color ,' ON']);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end

        function markerLEDOFF(obj,color)
             if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['Marker ', color ,' OFF']);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end

        %% functions to control the shocker
        %Set shock pattern param is a 16 binary bit pattern string.
        %Example: '1100110011001100', in which 1 means on and 0 means off. 
        function setShockPattern(obj,param)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['DIGITAL ', param]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function setShockPulse(obj,param)
            if  ~(obj.serialPort == 0)
                %['PULSE ', num2str(param.onTime),' ',num2str(param.onTime + param.offTime),' ',num2str(param.cycles), ' 0 ', ...
                %    num2str(param.delayTime),' 1 D']
                fprintf(obj.serialPort, ['PULSE ', num2str(param.onTime),' ',num2str(param.onTime + param.offTime),' ',num2str(param.cycles), ' 0 ', ...
                    num2str(param.delayTime),' 1 D']);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function turnOnShock(obj)
            if  ~(obj.serialPort == 0)
                % The first 0 means all panels, the second 0 means all
                % quadrants
                fprintf(obj.serialPort, 'DON');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function turnOffShock(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'DOFF');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        %The startPulse/stopPulse commands can control both LED and shock pulse. 
        %The following commands only control the shock.
        function startShockPulse(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'RUN D');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function stopShockPulse(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'STOP');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        %% functions to set up experiment protocols
        function totalSteps = addOneStep(obj,oneStep)
            if  ~(obj.serialPort == 0)   

                %check length of pulse set < duration for red led
                if (oneStep.RedIntensity > 0) && (oneStep.Duration < (oneStep.DelayTime + (oneStep.RedPulsePeriod * oneStep.RedPulseNum + oneStep.RedOffTime) * oneStep.RedIteration/1000))
                    errorMsg = sprintf("Length of red led pulse set is longer than duration in step %d!", oneStep.NumStep);
                    f = errordlg(errorMsg,'RED LED protocol Error');
                    return;
                end

                % Added this because the red indicator will be on if the
                % puslse width > 0
                if oneStep.RedIntensity == 0
                    oneStep.RedPulseWidth = 0;
                end

                %check length of pulse set < duration for green led
                if (oneStep.GrnIntensity > 0) && (oneStep.Duration < (oneStep.DelayTime + (oneStep.GrnPulsePeriod * oneStep.GrnPulseNum + oneStep.GrnOffTime) * oneStep.GrnIteration/1000))
                    errorMsg = sprintf("Length of green led pulse set is longer than duration in step %d!", oneStep.NumStep);
                    f = errordlg(errorMsg,'Green LED protocol Error');
                    return;
                end

                % Added this because the green indicator will be on if the
                % puslse width > 0
                if oneStep.GrnIntensity == 0
                    oneStep.GrnPulseWidth = 0;
                end

                %check length of pulse set < duration for blue led
                if (oneStep.BluIntensity > 0) && (oneStep.Duration < (oneStep.DelayTime + (oneStep.BluPulsePeriod * oneStep.BluPulseNum + oneStep.BluOffTime) * oneStep.BluIteration/1000))
                    errorMsg = sprintf("Length of blue led pulse set is longer than duration in step %d!", oneStep.NumStep);
                    f = errordlg(errorMsg,'Blue LED protocol Error');
                    return;
                end

                % Added this because the blue indicator will be on if the
                % puslse width > 0
                if oneStep.BluIntensity == 0
                    oneStep.BluPulseWidth = 0;
                end
                
                s = 'addOneStep ';                
                x = [oneStep.NumStep, oneStep.RedIntensity, oneStep.RedPulseWidth,...
                    oneStep.RedPulsePeriod, oneStep.RedPulseNum, oneStep.RedOffTime, oneStep.RedIteration, oneStep.GrnIntensity,...
                    oneStep.GrnPulseWidth, oneStep.GrnPulsePeriod, oneStep.GrnPulseNum, oneStep.GrnOffTime, oneStep.GrnIteration,...
                    oneStep.BluIntensity, oneStep.BluPulseWidth, oneStep.BluPulsePeriod, oneStep.BluPulseNum, oneStep.BluOffTime,...
                    oneStep.BluIteration,oneStep.DelayTime, oneStep.Duration];

                for i = 1:numel(x)
                    if isequaln(x(i),fix(x(i)))
                        s = [s,sprintf('%d ',x(i))];
                    else
                        s = [s,sprintf('%f ',x(i))];
                    end
                end

                if isfield(oneStep, 'Pattern')
                    fprintf(obj.serialPort, [s, ' ', oneStep.Pattern]);
                else
                    fprintf(obj.serialPort, s);
                end
                
                if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
                totalSteps = str2double(status);
            end
        end
        
        function removeAllExperimentSteps(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'removeAllSteps');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end             
        end        
                        
        function steps = getExperimentSteps(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'getExperimentSteps');
                if obj.docheckstatus, [~,steps] = checkControllerStatus(obj); end
            end
        end
        
        function runExperiment(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'runExperiment');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function stopExperiment(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'stopExperiment');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function status = getExperimentStatus(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'getExperimentStatus');
                if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
                status = status{1};
            end            
        end

        function stepOrder(obj,step)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['STEPORDER ',num2str(step)]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end


        function stepOrders = getExperimentStepOrders(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort,'STEPORDER ');
                if obj.docheckstatus, [~,stepOrders] = checkControllerStatus(obj); end
            end
        end

        function removeAllExperimentStepOrders(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'STEPORDER 0');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end             
        end   
        
        %%other functions       
        function synCamera(obj, freq)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['SYNC ', freq]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        function flyBowlsEnabled(obj, enableMap)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['enableMap ', enableMap]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end               
        end
        

        
        %It is used for Lisha's rig
        function setPattern(obj, pattern)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, ['ON 1 ', pattern(1:4)]);
                fprintf(obj.serialPort, ['ON 2 ', pattern(5:8)]);
                fprintf(obj.serialPort, ['ON 3 ', pattern(9:12)]);
                fprintf(obj.serialPort, ['ON 4 ', pattern(13:16)]);
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end
        end
        
        %reset controller, all power value reset to 0
        function reset(obj)
            if  ~(obj.serialPort == 0)
                fprintf(obj.serialPort, 'RESET');
                %if obj.docheckstatus, [~,status] = checkControllerStatus(obj); end
            end               
        end        
             
        function delete(obj)
            if  ~(obj.serialPort == 0)
                clear obj.serialPort;
            end
        end
        
        
    end
    
    methods (Access = private)
        function [checReslt,status] = checkControllerStatus(obj)
            %pause(0.1);
            starttime = tic;
            maxwaittime = .5;
            waittime = 0;
            while obj.serialPort.BytesAvailable <= 1
                waittime = toc(starttime);
                if waittime >= maxwaittime
                    break;
                end
            end
            fprintf('Waited %f seconds for controller status\n',waittime);
            status = {};
            while obj.serialPort.BytesAvailable > 1
                s = strtrim(fscanf(obj.serialPort));
                if isempty(s)
                    continue;
                end
                if obj.dispstatus
                    fprintf([s,'\n']);
                else
                    status{end+1} = s; %#ok<AGROW>
                end
            end
            checReslt = 1;
        end
    end
end