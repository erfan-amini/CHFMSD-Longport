% Main code for creating input files
% THe code need a scratch of XBeach params file to work on it
%
% Author: Erfan Amini
% Date: February 28, 2025
clc
clear all
close all

%% Input variables
number_of_scenarios = 7;
test_mode = false;  % Set to true to disable folder creation and file copying
plots = false;

% Constant across scenarios
CFL = 0.9;
eps = 0.005;
offshoreSpacing = 10;
shorelineSpacing = 0.2;
ah = 1;
bv = 0.005;

%% Scenrios:
vegetation_switch = [0 0 0 1 1 1 1]; % Switch on or off
Hsw = [0.9 0.9   0.9   1.1   1.1   1.0   1.0];
Av =  [0.0 0.0   0.0   25    25    36    36];
Nv =  [0.0 0.0   0.0   20    20    300   300];
SLR = [0.0 0.814 1.036 0.814 1.036 0.814 1.036];

%% Main 
if plots==true;vegplot=1;else;vegplot=0;end

for i = 1:number_of_scenarios
    % Mesh generation function
    [newX, newDepth, bedFriction, nx, keyLocations] = FFF_Mesh_Generation('seawallHeight',Hsw(i),'SLR',SLR(i),'createPlots',plots);
    stations = [0, struct2array(keyLocations)];
    % Vegrigidmap function
    FFF_Vegetation_Map_Generation('Vegetation',vegetation_switch(i),'VegLength',Av(i),'Plot',vegplot)
    % Changing params
    FFF_Modify_XBeach_Params({'vegetation','CFL', 'eps','nx'}, [vegetation_switch(i),CFL, eps, nx-1], stations, 'params.txt', './')
    % Change Vegetation charactristics
    FFF_Change_txt_files({'ah','bv','N'},[ah, bv, Nv(i)],'vegrigid.txt',pwd)
    
    % Skip folder creation and file copying if in test mode
    if ~test_mode
        % Create a new directory for this scenario (i-1 as a prefix to start from 00)
        scenario_folder = sprintf('%02d_Sandy_3_3_2025', i-1);
        if ~exist(scenario_folder, 'dir')
            mkdir(scenario_folder);
        end
        
        % List of files to copy
        files_to_copy = {'bed.txt', 'bedfricfile.txt', 'params.txt', 'vegrigid.txt', 'vegrigidmap.txt', 'x.txt', 'y.txt'};
        
        % Copy each file to the new directory
        for file_idx = 1:length(files_to_copy)
            current_file = files_to_copy{file_idx};
            if exist(current_file, 'file')
                copyfile(current_file, fullfile(scenario_folder, current_file));
            else
                warning('File %s does not exist and could not be copied for scenario %d.', current_file, i-1);
            end
        end
        
        % Copy all files from the "shared files" folder
        shared_folder = 'shared files';  % Path to the shared files folder
        if exist(shared_folder, 'dir')
            shared_files = dir(fullfile(shared_folder, '*'));
            for j = 1:length(shared_files)
                if ~shared_files(j).isdir && ~strcmp(shared_files(j).name, '.') && ~strcmp(shared_files(j).name, '..')
                    shared_file_path = fullfile(shared_folder, shared_files(j).name);
                    copyfile(shared_file_path, fullfile(scenario_folder, shared_files(j).name));
                end
            end
        else
            warning('Shared files folder "%s" does not exist.', shared_folder);
        end
        
        fprintf('Completed scenario %d (folder: %s)\n', i, scenario_folder);
    else
        fprintf('Test mode: Completed scenario %d (no folder created)\n', i);
    end
end
