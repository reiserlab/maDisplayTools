classdef DummyTestPlugin < handle
    % Minimal dummy class for testing ClassPlugin infrastructure
    %
    % Implements the required interface: initialize(), execute(), cleanup()
    % Tracks calls in public properties for test verification.

    properties
        name
        config
        logger
        initializeCalled = false
        cleanupCalled = false
        lastCommand = ''
        lastParams = struct()
        callCount = 0
    end

    methods
        function self = DummyTestPlugin(name, config, logger)
            self.name = name;
            self.config = config;
            self.logger = logger;
        end

        function initialize(self)
            self.initializeCalled = true;
            self.logger.log('INFO', sprintf('[%s] DummyTestPlugin initialized', self.name));
        end

        function result = execute(self, command, params)
            self.lastCommand = command;
            if exist('params', 'var')
                self.lastParams = params;
            end
            self.callCount = self.callCount + 1;
            self.logger.log('INFO', sprintf('[%s] DummyTestPlugin execute: %s', self.name, command));
            result = struct('success', true, 'command', command);
        end

        function cleanup(self)
            self.cleanupCalled = true;
            self.logger.log('INFO', sprintf('[%s] DummyTestPlugin cleaned up', self.name));
        end

        function status = getStatus(self)
            status = struct('name', self.name, 'calls', self.callCount);
        end
    end
end
