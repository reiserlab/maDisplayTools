function varargout = configure_arena(varargin)
% CONFIGURE_ARENA MATLAB code for configure_arena.fig
%      CONFIGURE_ARENA, by itself, creates a new CONFIGURE_ARENA or raises the existing
%      singleton*.
%
%      H = CONFIGURE_ARENA returns the handle to a new CONFIGURE_ARENA or the handle to
%      the existing singleton*.
%
%      CONFIGURE_ARENA('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in CONFIGURE_ARENA.M with the given input arguments.
%
%      CONFIGURE_ARENA('Property','Value',...) creates a new CONFIGURE_ARENA or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before configure_arena_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to configure_arena_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help configure_arena

% Last Modified by GUIDE v2.5 30-Apr-2017 11:50:42
% Updated 2026-01-25: Added generation selector and YAML export

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @configure_arena_OpeningFcn, ...
                   'gui_OutputFcn',  @configure_arena_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before configure_arena is made visible.
function configure_arena_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to configure_arena (see VARARGIN)

handles.gui1tag = findobj('Tag','Pattern_Generator_gui');

% Use cross-platform paths - try to find maDisplayTools root
thisFile = mfilename('fullpath');
[thisDir, ~, ~] = fileparts(thisFile);
[parentDir, ~, ~] = fileparts(thisDir);

% Check if we're in maDisplayTools structure
configsDir = fullfile(parentDir, 'configs', 'arenas');
if exist(configsDir, 'dir')
    handles.arena_folder = fullfile(parentDir, 'configs', 'arenas');
    handles.configs_root = parentDir;
else
    % Fallback to temp directory
    handles.arena_folder = tempdir;
    handles.configs_root = parentDir;
end
handles.scripts_folder = fullfile(parentDir, 'scripts');
handles.arena_file = 'arena_parameters.mat';
arena_fullfile = fullfile(handles.arena_folder, handles.arena_file);

% Generation options
handles.generations = {'G3', 'G4', 'G4.1', 'G6'};

try
    load(arena_fullfile,'aparam')
    % Determine generation from Psize
    handles.current_generation = psize_to_generation(aparam.Psize);
catch
    disp(['Could not locate ' arena_fullfile ', setting default parameters instead'])
    aparam.Psize = 16;
    aparam.Prows = 3;
    aparam.Pcols = 12;
    aparam.Pcircle = 18;
    aparam.rot180 = 0;
    aparam.rotations(1) = 0;
    aparam.rotations(2) = 0;
    aparam.rotations(3) = 0;
    aparam.translations(1) = 0;
    aparam.translations(2) = 0;
    aparam.translations(3) = 0;
    aparam.model = 'polygonal cylinder';
    handles.current_generation = 'G4';
end

% Store initial aparam
handles.aparam = aparam;

set(handles.edit1, 'String',num2str(aparam.Psize));
set(handles.edit2, 'String',num2str(aparam.Prows));
set(handles.edit3, 'String',num2str(aparam.Pcols));
set(handles.edit4, 'String',num2str(aparam.Pcircle));
set(handles.checkbox1, 'Value', aparam.rot180);
set(handles.edit5, 'String',num2str(aparam.rotations(1)));
set(handles.edit6, 'String',num2str(aparam.rotations(2)));
set(handles.edit7, 'String',num2str(aparam.rotations(3)));
set(handles.edit8, 'String',num2str(aparam.translations(1)));
set(handles.edit9, 'String',num2str(aparam.translations(2)));
set(handles.edit10, 'String',num2str(aparam.translations(3)));

popup_val = find(strncmpi(aparam.model,{'p' 's'},1));
set(handles.popupmenu1, 'Value',popup_val);

% Add generation selector programmatically
fig_pos = get(hObject, 'Position');
handles = add_generation_controls(hObject, handles, fig_pos);

% Choose default command line output for configure_arena
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes configure_arena wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Add generation selector and YAML buttons programmatically
function handles = add_generation_controls(hObject, handles, fig_pos)
% Add generation dropdown, Load YAML, and Save YAML buttons

% Get current figure size to position new controls
fig_height = fig_pos(4);

% Generation label
handles.text_gen = uicontrol('Parent', hObject, ...
    'Style', 'text', ...
    'String', 'Generation:', ...
    'Position', [10 fig_height-30 70 20], ...
    'HorizontalAlignment', 'left');

% Generation dropdown
gen_idx = find(strcmp(handles.generations, handles.current_generation));
if isempty(gen_idx), gen_idx = 2; end  % Default to G4
handles.popup_generation = uicontrol('Parent', hObject, ...
    'Style', 'popupmenu', ...
    'String', handles.generations, ...
    'Value', gen_idx, ...
    'Position', [80 fig_height-30 60 22], ...
    'Callback', @(src,evt) generation_changed(src, evt, guidata(src)));

% Load YAML button
handles.btn_load_yaml = uicontrol('Parent', hObject, ...
    'Style', 'pushbutton', ...
    'String', 'Load YAML', ...
    'Position', [150 fig_height-30 70 22], ...
    'Callback', @(src,evt) load_yaml_callback(src, evt, guidata(src)));

% Save YAML button
handles.btn_save_yaml = uicontrol('Parent', hObject, ...
    'Style', 'pushbutton', ...
    'String', 'Save YAML', ...
    'Position', [225 fig_height-30 70 22], ...
    'Callback', @(src,evt) save_yaml_callback(src, evt, guidata(src)));


% --- Generation changed callback
function generation_changed(hObject, eventdata, handles)
% Update Psize when generation changes
gens = get(handles.popup_generation, 'String');
gen_idx = get(handles.popup_generation, 'Value');
generation = gens{gen_idx};

% Get specs from single source of truth
try
    specs = get_generation_specs(generation);
    set(handles.edit1, 'String', num2str(specs.pixels_per_panel));
    handles.current_generation = generation;
    guidata(hObject, handles);
catch ME
    errordlg(['Error loading generation specs: ' ME.message], 'Generation Error');
end


% --- Load YAML callback
function load_yaml_callback(hObject, eventdata, handles)
% Load arena config from YAML file
[filename, pathname] = uigetfile({'*.yaml;*.yml', 'YAML Files (*.yaml, *.yml)'}, ...
    'Select Arena Configuration', handles.arena_folder);
if isequal(filename, 0)
    return;  % User cancelled
end

try
    config = load_arena_config(fullfile(pathname, filename));

    % Update UI with loaded values
    specs = get_generation_specs(config.arena.generation);
    set(handles.edit1, 'String', num2str(specs.pixels_per_panel));
    set(handles.edit2, 'String', num2str(config.arena.num_rows));
    set(handles.edit3, 'String', num2str(config.arena.num_cols));
    set(handles.edit4, 'String', num2str(config.arena.num_cols));  % Pcircle = num_cols for full arena

    % Update generation dropdown
    gen_idx = find(strcmp(handles.generations, config.arena.generation));
    if ~isempty(gen_idx)
        set(handles.popup_generation, 'Value', gen_idx);
    end

    % Update orientation checkbox (rot180)
    rot180 = strcmp(config.arena.orientation, 'upside_down');
    set(handles.checkbox1, 'Value', rot180);

    % Load extended fields if present (rotations, translations, model)
    if isfield(config.arena, 'rotations_deg')
        rots = config.arena.rotations_deg;
        set(handles.edit5, 'String', num2str(rots(1)));
        set(handles.edit6, 'String', num2str(rots(2)));
        set(handles.edit7, 'String', num2str(rots(3)));
    end
    if isfield(config.arena, 'translations')
        trans = config.arena.translations;
        set(handles.edit8, 'String', num2str(trans(1)));
        set(handles.edit9, 'String', num2str(trans(2)));
        set(handles.edit10, 'String', num2str(trans(3)));
    end
    if isfield(config.arena, 'cylinder_model')
        model_val = find(strncmpi(config.arena.cylinder_model, {'p' 's'}, 1));
        if ~isempty(model_val)
            set(handles.popupmenu1, 'Value', model_val);
        end
    end

    handles.current_generation = config.arena.generation;
    guidata(hObject, handles);

    msgbox(['Loaded: ' filename], 'Config Loaded');
catch ME
    errordlg(['Error loading YAML: ' ME.message], 'Load Error');
end


% --- Save YAML callback
function save_yaml_callback(hObject, eventdata, handles)
% Save current configuration as YAML

% Get current values
Psize = str2double(get(handles.edit1, 'String'));
Prows = str2double(get(handles.edit2, 'String'));
Pcols = str2double(get(handles.edit3, 'String'));
rot180 = get(handles.checkbox1, 'Value');

% Get generation from dropdown
gens = get(handles.popup_generation, 'String');
gen_idx = get(handles.popup_generation, 'Value');
generation = gens{gen_idx};

% Get rotations/translations
rotations = [str2double(get(handles.edit5, 'String')), ...
             str2double(get(handles.edit6, 'String')), ...
             str2double(get(handles.edit7, 'String'))];
translations = [str2double(get(handles.edit8, 'String')), ...
                str2double(get(handles.edit9, 'String')), ...
                str2double(get(handles.edit10, 'String'))];

% Get cylinder model
popup_strings = {'poly', 'smooth'};
model = popup_strings{get(handles.popupmenu1, 'Value')};

% Generate default filename
default_name = sprintf('%s_%dx%d_full.yaml', generation, Prows, Pcols);

% Get save location
[filename, pathname] = uiputfile({'*.yaml', 'YAML Files (*.yaml)'}, ...
    'Save Arena Configuration', fullfile(handles.arena_folder, default_name));
if isequal(filename, 0)
    return;  % User cancelled
end

% Build YAML content
yaml_content = sprintf('# Arena configuration for %s display\n', generation);
yaml_content = [yaml_content sprintf('# Generated by configure_arena on %s\n\n', datestr(now, 'yyyy-mm-dd'))];
yaml_content = [yaml_content sprintf('format_version: "1.0"\n')];

% Generate name from filename
[~, config_name, ~] = fileparts(filename);
yaml_content = [yaml_content sprintf('name: "%s"\n', config_name)];
yaml_content = [yaml_content sprintf('description: "%s arena, %d rows x %d columns"\n\n', generation, Prows, Pcols)];

yaml_content = [yaml_content sprintf('arena:\n')];
yaml_content = [yaml_content sprintf('  generation: "%s"\n', generation)];
yaml_content = [yaml_content sprintf('  num_rows: %d\n', Prows)];
yaml_content = [yaml_content sprintf('  num_cols: %d\n', Pcols)];
yaml_content = [yaml_content sprintf('  columns_installed: null    # null = all columns installed\n')];

% orientation maps to rot180
if rot180
    yaml_content = [yaml_content sprintf('  orientation: "upside_down"\n')];
else
    yaml_content = [yaml_content sprintf('  orientation: "normal"\n')];
end

yaml_content = [yaml_content sprintf('  column_order: "cw"\n')];
yaml_content = [yaml_content sprintf('  angle_offset_deg: 0\n')];

% Add extended fields if non-default
if any(rotations ~= 0)
    yaml_content = [yaml_content sprintf('  rotations_deg: [%.4g, %.4g, %.4g]\n', rotations(1), rotations(2), rotations(3))];
end
if any(translations ~= 0)
    yaml_content = [yaml_content sprintf('  translations: [%.4g, %.4g, %.4g]\n', translations(1), translations(2), translations(3))];
end
if ~strcmp(model, 'poly')
    yaml_content = [yaml_content sprintf('  cylinder_model: "%s"\n', model)];
end

% Write file
try
    fid = fopen(fullfile(pathname, filename), 'w');
    fprintf(fid, '%s', yaml_content);
    fclose(fid);
    msgbox(['Saved: ' filename], 'Config Saved');
catch ME
    errordlg(['Error saving YAML: ' ME.message], 'Save Error');
end


% --- Helper: Convert Psize to generation
function gen = psize_to_generation(Psize)
switch Psize
    case 8
        gen = 'G3';
    case 16
        gen = 'G4';  % Could be G4 or G4.1
    case 20
        gen = 'G6';
    otherwise
        gen = 'G4';  % Default
end


% --- Outputs from this function are returned to the command line.
function varargout = configure_arena_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double


% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double


% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double


% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double


% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit7_Callback(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit7 as text
%        str2double(get(hObject,'String')) returns contents of edit7 as a double


% --- Executes during object creation, after setting all properties.
function edit7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit8_Callback(hObject, eventdata, handles)
% hObject    handle to edit8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit8 as text
%        str2double(get(hObject,'String')) returns contents of edit8 as a double


% --- Executes during object creation, after setting all properties.
function edit8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit9_Callback(hObject, eventdata, handles)
% hObject    handle to edit9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit9 as text
%        str2double(get(hObject,'String')) returns contents of edit9 as a double


% --- Executes during object creation, after setting all properties.
function edit9_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit10_Callback(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit10 as text
%        str2double(get(hObject,'String')) returns contents of edit10 as a double


% --- Executes during object creation, after setting all properties.
function edit10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

Psize = str2double(get(handles.edit1, 'String'));
Prows = str2double(get(handles.edit2, 'String'));
Pcols = str2double(get(handles.edit3, 'String'));
Pcircle = str2double(get(handles.edit4, 'String'));
rot180 = get(handles.checkbox1, 'Value');
popup_strings = {'poly', 'smooth'};
model = popup_strings{get(handles.popupmenu1, 'Value')};
rotations = [str2double(get(handles.edit5, 'String')), str2double(get(handles.edit6, 'String')), str2double(get(handles.edit7, 'String'))];
translations = [str2double(get(handles.edit8, 'String')), str2double(get(handles.edit9, 'String')), str2double(get(handles.edit10, 'String'))];

arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, fullfile(handles.arena_folder, handles.arena_file))

s3data.arena_pitch = rad2deg(rotations(2));
s3data.updated = 1;
if isempty(handles.gui1tag)==0
    setappdata(handles.gui1tag,'s3data',s3data);
end

close(gcf)


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject, 'String', {'polygonal cylinder', 'smooth cylinder'});


% --- Executes on button press in checkbox1.
function checkbox1_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox1
