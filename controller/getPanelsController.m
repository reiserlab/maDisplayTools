function pc = getPanelsController(hostName, port, options)
%% getPanelsController Singleton façade for PanelsController
%
% Returns the existing PanelsController instance for a given host+port
% combination, or creates and registers a new one if none exists. This
% prevents multiple TCP connections to the same hardware, which can cause
% socket deadlocks on Windows.
%
% PanelsController itself is unchanged and can still be called directly by
% existing code. This function is the recommended entry point for new code.
%
% Arguments:
%   hostName  - (optional) hostname or IP of the G4 Host machine.
%               Defaults to PanelsController.defaultHostName ('localhost').
%   port      - (optional) TCP port of the G4 Host.
%               Defaults to PanelsController.defaultPort (62222).
%
% Options:
%   reset     - (logical, default false) If true, close and discard the
%               existing instance for this host+port before creating a new
%               one. Useful for recovering from a broken connection.
%
% Returns:
%   pc        - A PanelsController handle. If an open instance already
%               exists for this host+port, that same handle is returned.
%               If not, a new PanelsController is constructed and stored.
%
% Usage:
%   pc = getPanelsController();
%   pc = getPanelsController('192.168.1.10');
%   pc = getPanelsController('192.168.1.10', 62222);
%   pc = getPanelsController('localhost', 62222, reset=true);
%
% To release the stored instance manually (e.g. after a crash where
% close() was never called):
%   getPanelsController('localhost', reset=true);
%
% see also PanelsController, PanelsController/open, PanelsController/close

    arguments
        hostName (1,1) string = PanelsController.defaultHostName
        port     (1,1) double = PanelsController.defaultPort
        options.reset (1,1) logical = false
    end

    % registry is a persistent struct array with fields 'key' and 'instance'
    persistent registry;
    if isempty(registry)
        registry = struct('key', {}, 'instance', {});
    end

    key = sprintf('%s:%d', hostName, port);

    % Find index of any existing entry for this key
    existingIdx = [];
    for i = 1:numel(registry)
        if strcmp(registry(i).key, key)
            existingIdx = i;
            break;
        end
    end

    % If reset requested, close and remove the existing instance
    if options.reset && ~isempty(existingIdx)
        existing = registry(existingIdx).instance;
        if existing.isOpen
            existing.close();
        end
        registry(existingIdx) = [];
        existingIdx = [];
        fprintf('getPanelsController: reset instance for %s\n', key);
    end

    % Return existing instance if one is registered
    if ~isempty(existingIdx)
        pc = registry(existingIdx).instance;
        fprintf('getPanelsController: returning existing instance for %s\n', key);
        return;
    end

    % No existing instance — create, register, and return a new one
    pc = PanelsController(char(hostName), port);
    registry(end+1) = struct('key', key, 'instance', pc);
    fprintf('getPanelsController: created new instance for %s\n', key);

end
