function root = project_root()
% PROJECT_ROOT Return the absolute path to the maDisplayTools repo root.
%
%   root = project_root()
%
%   Auto-detects the project root by walking up from this file's location.
%   Works on macOS, Windows, and Linux — no hardcoded paths needed.
%
%   Usage in test/example scripts (replaces hardcoded cd):
%       cd(project_root());
%       addpath(genpath('.'));
%
%   Examples:
%       >> project_root()
%       '/Users/reiserm/Documents/GitHub/maDisplayTools'    % macOS
%       'C:\users\labadmin\matlabroot\maDisplayTools'       % Windows lab PC

%   This file lives in utils/, so the repo root is one level up.
    thisFile = mfilename('fullpath');       % .../maDisplayTools/utils/project_root
    utilsDir = fileparts(thisFile);         % .../maDisplayTools/utils
    root     = fileparts(utilsDir);         % .../maDisplayTools
end
