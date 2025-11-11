%% SFINCS to FAST GeoTIFF Converter (MATLAB-only version)
% Creates GeoTIFFs with world files for FEMA FAST without requiring GDAL

clear all;
close all;
clc;

%% User Configuration Settings
base_folder = '.';
control_folder = '0';
scenario_folders = {'1', '2', '3', '4', '5', '6'};
all_folders = [{control_folder}, scenario_folders];
nc_filename = 'sfincs_map.nc';

output_folder = './FAST_Rasters';
output_filename_prefix = 'Longport_Flood_Depth_Scenario_';

meters_to_feet = 3.28084;
nodata_value = -3.4028230607370965e+38; % Match the Oahu sample nodata value

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% Process each scenario
fprintf('Converting SFINCS flood data to FAST format...\n');

for folder_idx = 1:length(all_folders)
    current_folder = all_folders{folder_idx};
    
    fprintf('Processing Scenario %s... ', current_folder);
    
    input_file = fullfile(base_folder, current_folder, nc_filename);
    
    if ~exist(input_file, 'file')
        fprintf('File not found. Skipping.\n');
        continue;
    end
    
    try
        % Read data
        hmax = ncread(input_file, 'hmax');
        if ndims(hmax) == 3
            hmax = hmax(:,:,end);
        end
        
        x_grid = ncread(input_file, 'x'); 
        y_grid = ncread(input_file, 'y');
        
        % Process flood depth data
        flood_depth = double(hmax);
        
        % Handle invalid values
        flood_depth(isnan(flood_depth) | flood_depth < 0) = nodata_value;
        
        % Convert from meters to feet for FAST
        valid_cells = flood_depth ~= nodata_value;
        flood_depth(valid_cells) = flood_depth(valid_cells) * meters_to_feet;
        
        % Calculate grid parameters
        x_min = min(x_grid(:));
        y_max = max(y_grid(:));
        x_size = abs((max(x_grid(:)) - x_min) / (length(x_grid) - 1));
        y_size = abs((y_max - min(y_grid(:))) / (length(y_grid) - 1));
        
        % Output file path
        output_filename = sprintf('%s%s.tif', output_filename_prefix, current_folder);
        output_path = fullfile(output_folder, output_filename);
        
        % Write TIFF file using Tiff class for more control
        t = Tiff(output_path, 'w');
        
        % Configure TIFF tags
        tagstruct.ImageLength = size(flood_depth, 1);
        tagstruct.ImageWidth = size(flood_depth, 2);
        tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 32;
        tagstruct.SamplesPerPixel = 1;
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        tagstruct.Software = 'MATLAB';
        
        % Try to add GeoTIFF tags if possible
        try
            % Basic geospatial tags
            tagstruct.ModelPixelScaleTag = [x_size; y_size; 0];
            tagstruct.ModelTiepointTag = [0; 0; 0; x_min; y_max; 0];
        catch
            % If GeoTIFF tags aren't supported, we'll rely on world file
            fprintf('GeoTIFF tags not supported, using world file method instead.\n');
        end
        
        % Set tags and write the data
        t.setTag(tagstruct);
        t.write(single(flood_depth));
        t.close();
        
        % Create world file (.tfw)
        worldfile_path = fullfile(output_folder, [output_filename_prefix, current_folder, '.tfw']);
        fid = fopen(worldfile_path, 'w');
        fprintf(fid, '%.12f\n', x_size);           % pixel size in x
        fprintf(fid, '0.0\n');                     % rotation term
        fprintf(fid, '0.0\n');                     % rotation term
        fprintf(fid, '%.12f\n', -y_size);          % pixel size in y (negative)
        fprintf(fid, '%.12f\n', x_min);            % x of upper left
        fprintf(fid, '%.12f\n', y_max);            % y of upper left
        fclose(fid);
        
        % Create projection file (.prj)
        prj_path = fullfile(output_folder, [output_filename_prefix, current_folder, '.prj']);
        fid = fopen(prj_path, 'w');
        fprintf(fid, ['PROJCS["NAD_1983_UTM_Zone_18N",', ...
                    'GEOGCS["GCS_North_American_1983",', ...
                    'DATUM["D_North_American_1983",', ...
                    'SPHEROID["GRS_1980",6378137.0,298.257222101]],', ...
                    'PRIMEM["Greenwich",0.0],', ...
                    'UNIT["Degree",0.0174532925199433]],', ...
                    'PROJECTION["Transverse_Mercator"],', ...
                    'PARAMETER["False_Easting",500000.0],', ...
                    'PARAMETER["False_Northing",0.0],', ...
                    'PARAMETER["Central_Meridian",-75.0],', ...
                    'PARAMETER["Scale_Factor",0.9996],', ...
                    'PARAMETER["Latitude_Of_Origin",0.0],', ...
                    'UNIT["Meter",1.0]]']);
        fclose(fid);
        
        % Create an auxiliary XML file to specify NoData value
        aux_path = fullfile(output_folder, [output_path, '.aux.xml']);
        fid = fopen(aux_path, 'w');
        fprintf(fid, ['<PAMDataset>\n', ...
                     '  <PAMRasterBand band="1">\n', ...
                     '    <NoDataValue>%.17g</NoDataValue>\n', ...
                     '  </PAMRasterBand>\n', ...
                     '</PAMDataset>'], nodata_value);
        fclose(fid);
        
        fprintf('Done.\n');
    catch ME
        fprintf('Error: %s\n', ME.message);
        fprintf('Stack: %s\n', getReport(ME, 'extended'));
    end
end

fprintf('\nConversion complete. Files saved to %s\n', output_folder);
fprintf('Place these files in the "Rasters" subfolder of FAST.\n');
