# CHFMSD Framework-Longport
(Coastal Hybrid Flood Mitigation System Dataset for Longport, NJ, USA)

[![DOI](https://img.shields.io/badge/DOI-pending-blue)](link-to-doi)
[![License](https://img.shields.io/badge/License-Research-green)](LICENSE)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2019b+-orange.svg)](https://www.mathworks.com/products/matlab.html)

## Overview

This repository contains the computational results, analysis codes, and complete processing workflow for an integrated modeling framework evaluating the effectiveness of hybrid vegetation-seawall systems in mitigating coastal flooding under present and future sea level rise scenarios. The research focuses on Longport, New Jersey, using Hurricane Sandy (2012) as a test case to assess the performance of nature-based solutions integrated with traditional coastal defense structures.

## Research Background

As coastal communities face increasing threats from sea level rise and extreme weather events, traditional coastal defense structures like seawalls are becoming insufficient on their own. This study investigates how integrating vegetation with seawalls can enhance coastal resilience while providing economic benefits through a comprehensive cost-benefit analysis.

### Study Methodology

The research employs an integrated modeling approach that sequentially couples three established models:

1. **XBeach Non-Hydrostatic (XBNH)** - Phase-resolving wave model for wave propagation, transformation, and overtopping simulation
2. **SFINCS (Super-Fast Inundation of CoastS)** - Reduced-complexity hydrodynamic model for street-scale urban flooding simulation
3. **FEMA's Flood Assessment Structure Tool (FAST)** - Economic damage assessment tool for building-level flood damage quantification

## Repository Structure

```
CHFMSD-Framework-Longport/
│
├── README.md                              # This file
├── LICENSE                                # License information
│
├── processing_codes/                      # MATLAB processing scripts
│   ├── 1_WaveModelCreation.m             # XBeach input file generator
│   ├── 2_WaveModel_to_FloodModel.m       # Overtopping data processor
│   ├── 3_FloodModel_to_DamageModel.m     # SFINCS to FAST converter
│   └── params.txt                         # XBeach parameter template
│
├── results/                               # Model output data
│   ├── case_00_results.mat               # Control scenario (2012)
│   ├── case_01_results.mat               # CS + Low emission SLR
│   ├── case_02_results.mat               # CS + High emission SLR
│   ├── case_03_results.mat               # Design I + Low SLR
│   ├── case_04_results.mat               # Design I + High SLR
│   ├── case_05_results.mat               # Design II + Low SLR
│   ├── case_06_results.mat               # Design II + High SLR
│   └── overtopping_summary.mat           # Consolidated analysis
│
├── sfincs_outputs/                        # SFINCS NetCDF files
│   ├── SFINCS_case_00.nc
│   ├── SFINCS_case_01.nc
│   ├── SFINCS_case_02.nc
│   ├── SFINCS_case_03.nc
│   ├── SFINCS_case_04.nc
│   ├── SFINCS_case_05.nc
│   └── SFINCS_case_06.nc
│
├── fast_rasters/                          # GeoTIFF flood depth maps
│   ├── Longport_Flood_Depth_Scenario_0.tif
│   ├── Longport_Flood_Depth_Scenario_1.tif
│   └── ...
│
└── documentation/                         # Additional documentation
    ├── model_validation.pdf
    ├── scenario_descriptions.pdf
    └── data_dictionary.xlsx
```

## Processing Codes

### 1. Wave Model Creation (`1_WaveModelCreation.m`)

Generates XBeach input files for all scenarios with configurable parameters. This script reads the template `params.txt` file and creates scenario-specific configurations.

#### Features
- Automated mesh generation with variable resolution (10m offshore to 10cm nearshore)
- Beach profile integration with seawall configuration
- Vegetation map generation for hybrid scenarios
- Parameter file modification for each scenario
- Batch processing of multiple scenarios
- Test mode for debugging without file creation

#### Key Configuration Parameters
```matlab
number_of_scenarios = 7;               % Total scenarios to generate
test_mode = false;                     % Set to true for testing
plots = false;                         % Enable visualization

% Physical constants
CFL = 0.9;                            % Courant number
eps = 0.005;                          % Epsilon for wave breaking
offshoreSpacing = 10;                 % Grid spacing offshore (m)
shorelineSpacing = 0.2;               % Grid spacing nearshore (m)
ah = 1;                               % Vegetation height (m)
bv = 0.005;                           % Vegetation stem diameter (m)

% Scenario-specific parameters
vegetation_switch = [0 0 0 1 1 1 1];  % Vegetation on/off
Hsw = [0.9 0.9 0.9 1.1 1.1 1.0 1.0]; % Seawall heights (m)
Av  = [0.0 0.0 0.0 25  25  36  36];  % Vegetation area (m²/m)
Nv  = [0.0 0.0 0.0 20  20  300 300]; % Vegetation density (stems/m²)
SLR = [0.0 0.814 1.036 0.814 1.036 0.814 1.036]; % Sea level rise (m)
```

#### Required Input Files
- `params.txt` - XBeach parameter template file
- Beach profile data (embedded in code)
- `shared files/` folder containing:
  - `jonswap_table.txt` - Wave spectrum boundary conditions
  - `stormtide.txt` - Hurricane Sandy storm tide time series
  - Other XBeach configuration files

#### Output Structure
The script creates numbered folders for each scenario:
```
00_Sandy_3_3_2025/
├── bed.txt              # Bathymetry/topography
├── bedfricfile.txt      # Manning roughness coefficients
├── params.txt           # XBeach parameters (scenario-specific)
├── vegrigid.txt         # Vegetation characteristics
├── vegrigidmap.txt      # Vegetation spatial distribution
├── x.txt                # X-coordinates
├── y.txt                # Y-coordinates
├── jonswap_table.txt    # Wave boundary conditions
└── stormtide.txt        # Water level forcing
```

#### Usage Example
```matlab
% Basic usage - generate all scenarios
run('1_WaveModelCreation.m');

% Test mode - check configuration without creating files
test_mode = true;
plots = true;
run('1_WaveModelCreation.m');

% Custom scenarios - modify parameters before running
Hsw = [0.9 1.0 1.1 1.2];  % Test 4 seawall heights
number_of_scenarios = 4;
run('1_WaveModelCreation.m');
```

#### Functions Called
- `FFF_Mesh_Generation()` - Creates variable-resolution computational grid
- `FFF_Vegetation_Map_Generation()` - Generates spatial vegetation distribution
- `FFF_Modify_XBeach_Params()` - Updates parameter file for each scenario
- `FFF_Change_txt_files()` - Modifies vegetation characteristic files

---

### 2. Wave Model to Flood Model (`2_WaveModel_to_FloodModel.m`)

Extracts and processes XBeach overtopping results for SFINCS input, bridging the temporal scale gap between phase-resolving wave models and reduced-complexity flood models.

#### Features
- Multi-stage signal processing with advanced smoothing techniques
- Temporal scale bridging (sub-second wave resolution to minute-scale flooding)
- Volume conservation verification (±5% tolerance)
- Automated visualization comparing raw and processed data
- Batch processing of multiple scenarios
- Quality control with statistical reporting

#### Key Configuration Parameters
```matlab
% Input/output paths
input_mat_file = './overtopping_results/overtopping_summary.mat';
output_folder = './extracted_data';

% Processing parameters
smoothing_window_minutes = 20.0;    % Smoothing window size
process_scenarios = 2;              % Scenarios to process (0-6)
scenario_to_plot = 2;               % Scenario for visualization

% Plot settings
y_axis_max = 1.0;                   % Maximum discharge for plots (m³/s/m)

% Reference time
ref_date = datetime(2012, 10, 27, 8, 40, 0);  % Hurricane Sandy start
```

#### Processing Methodology

**Step 1: Data Loading**
- Reads raw overtopping time series from XBeach results
- Accesses time vectors and discharge data for each scenario
- Validates data structure and dimensions

**Step 2: Data Cleaning**
```matlab
% Replace NaN values with zeros
time_series(isnan(time_series)) = 0;

% Log original data statistics
fprintf('Original data range: min=%.2f, max=%.2f\n', ...
        min(time_series), max(time_series));
```

**Step 3: Multi-Stage Smoothing**

*First Pass: Gaussian Smoothing*
```matlab
% Calculate window size (1200 points for 20-minute window)
minute_window = round(smoothing_window_minutes * 60);

% Apply Gaussian filter
smooth_series = smoothdata(smooth_series, 'gaussian', ...
                          minute_window, 'includenan');
```

*Second Pass: Savitzky-Golay Filter*
```matlab
% Preserve peak magnitudes with polynomial regression
poly_order = 3;
sg_window = min(minute_window, 501);  % Must be odd
smooth_series = sgolayfilt(smooth_series, poly_order, sg_window);
```

**Step 4: Physical Constraints**
```matlab
% Remove negative values (physically unrealistic)
smooth_series(smooth_series < 0) = 0;

% Preserve zero periods (no overtopping)
% Automatically handled by smoothing algorithm
```

**Step 5: Quality Control**
```matlab
% Volume conservation check
original_volume = sum(orig_time_series) * dt;
processed_volume = sum(smooth_series) * dt;
volume_error = abs(processed_volume - original_volume) / original_volume;

if volume_error > 0.05
    warning('Volume conservation error: %.2f%%', volume_error*100);
end
```

#### Output Files

**SFINCS Boundary Condition Files**
```
scenario_X_for_sfincs.txt format:
Time_seconds,Scenario_X
0.00,0.00
1.00,0.05
2.00,0.12
...
```

**Visualization Files**
- `scenario_X_plot.png` - Comparison of raw vs. processed data
- `scenario_X_plot_data.mat` - MATLAB data for custom plotting

**Summary Statistics**
- `scenarios_summary.txt` - Processing metadata for all scenarios

#### Usage Example
```matlab
% Process all scenarios
process_scenarios = 0:6;
run('2_WaveModel_to_FloodModel.m');

% Process and visualize specific scenario
process_scenarios = 2;
scenario_to_plot = 2;
smoothing_window_minutes = 15.0;  % Less aggressive smoothing
run('2_WaveModel_to_FloodModel.m');

% High-resolution output for detailed analysis
smoothing_window_minutes = 10.0;
y_axis_max = 2.0;  % Adjust plot scale
run('2_WaveModel_to_FloodModel.m');
```

#### Validation Checks

The script performs automatic validation:
- Checks for negative discharge values
- Verifies time vector continuity
- Reports number of zero-value periods preserved
- Calculates and reports peak discharge changes
- Samples data points throughout the time series

#### Troubleshooting

**Issue**: Smoothing removes too much detail
```matlab
% Solution: Reduce smoothing window
smoothing_window_minutes = 10.0;  % Default is 20.0
```

**Issue**: Volume not conserved
```matlab
% Solution: Check for data gaps or extreme values
% Inspect raw data before processing
load('overtopping_summary.mat');
plot(sorted_timeseries{scenario_idx+1});
```

**Issue**: Negative values appearing after smoothing
```matlab
% Solution: Automatically handled by post-processing
% Check this warning in output:
% "Replacing X negative values with 0 after smoothing"
```

---

### 3. Flood Model to Damage Model (`3_FloodModel_to_DamageModel.m`)

Converts SFINCS flood depth outputs to GeoTIFF format compatible with FEMA FAST for economic damage assessment. This script handles spatial reference systems, unit conversions, and FAST-specific formatting requirements.

#### Features
- Batch processing of all scenarios
- Automatic unit conversion (meters to feet for FAST)
- GeoTIFF creation with embedded spatial reference
- World file (.tfw) generation for legacy GIS compatibility
- Projection file (.prj) in WKT format
- Auxiliary XML file for NoData value specification
- NoData handling compatible with FAST requirements

#### Key Configuration Parameters
```matlab
% Directory structure
base_folder = '.';                    % SFINCS output location
control_folder = '0';                 % Control scenario folder
scenario_folders = {'1', '2', '3', '4', '5', '6'};
nc_filename = 'sfincs_map.nc';       % SFINCS output file name

% Output configuration
output_folder = './FAST_Rasters';
output_filename_prefix = 'Longport_Flood_Depth_Scenario_';

% Conversion parameters
meters_to_feet = 3.28084;            % FAST requires feet
nodata_value = -3.4028230607370965e+38;  % FAST-compatible NoData
```

#### Processing Steps

**Step 1: Read SFINCS Output**
```matlab
% Load maximum flood depth from NetCDF
hmax = ncread(input_file, 'hmax');
if ndims(hmax) == 3
    hmax = hmax(:,:,end);  % Extract final time step
end

% Load spatial coordinates
x_grid = ncread(input_file, 'x'); 
y_grid = ncread(input_file, 'y');
```

**Step 2: Data Processing**
```matlab
% Convert to double precision
flood_depth = double(hmax);

% Handle invalid values
flood_depth(isnan(flood_depth) | flood_depth < 0) = nodata_value;

% Convert meters to feet
valid_cells = flood_depth ~= nodata_value;
flood_depth(valid_cells) = flood_depth(valid_cells) * meters_to_feet;
```

**Step 3: Calculate Geospatial Parameters**
```matlab
% Grid parameters for UTM Zone 18N
x_min = min(x_grid(:));
y_max = max(y_grid(:));
x_size = abs((max(x_grid(:)) - x_min) / (length(x_grid) - 1));
y_size = abs((y_max - min(y_grid(:))) / (length(y_grid) - 1));

% Typical values for Longport:
% x_size ≈ 1.5 m
% y_size ≈ 1.5 m
% Projection: NAD83 UTM Zone 18N (EPSG:26918)
```

**Step 4: GeoTIFF Creation**
```matlab
% Configure TIFF tags
t = Tiff(output_path, 'w');
tagstruct.ImageLength = size(flood_depth, 1);
tagstruct.ImageWidth = size(flood_depth, 2);
tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;  % Float32
tagstruct.BitsPerSample = 32;
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;

% Add GeoTIFF tags
tagstruct.ModelPixelScaleTag = [x_size; y_size; 0];
tagstruct.ModelTiepointTag = [0; 0; 0; x_min; y_max; 0];

% Write data
t.setTag(tagstruct);
t.write(single(flood_depth));
t.close();
```

**Step 5: Create Auxiliary Files**

*World File (.tfw)*
```
1.500000000000    # Pixel size in X
0.0               # Rotation about Y-axis
0.0               # Rotation about X-axis
-1.500000000000   # Pixel size in Y (negative)
540000.000000     # X coordinate of upper-left pixel center
4351000.000000    # Y coordinate of upper-left pixel center
```

*Projection File (.prj)*
```
PROJCS["NAD_1983_UTM_Zone_18N",
  GEOGCS["GCS_North_American_1983",
    DATUM["D_North_American_1983",
      SPHEROID["GRS_1980",6378137.0,298.257222101]],
    PRIMEM["Greenwich",0.0],
    UNIT["Degree",0.0174532925199433]],
  PROJECTION["Transverse_Mercator"],
  PARAMETER["False_Easting",500000.0],
  PARAMETER["False_Northing",0.0],
  PARAMETER["Central_Meridian",-75.0],
  PARAMETER["Scale_Factor",0.9996],
  PARAMETER["Latitude_Of_Origin",0.0],
  UNIT["Meter",1.0]]
```

*Auxiliary XML (.aux.xml)*
```xml
<PAMDataset>
  <PAMRasterBand band="1">
    <NoDataValue>-3.4028230607370965e+38</NoDataValue>
  </PAMRasterBand>
</PAMDataset>
```

#### Output File Structure

For each scenario, the following files are created:

```
FAST_Rasters/
├── Longport_Flood_Depth_Scenario_0.tif       # GeoTIFF (main file)
├── Longport_Flood_Depth_Scenario_0.tfw       # World file
├── Longport_Flood_Depth_Scenario_0.prj       # Projection file
├── Longport_Flood_Depth_Scenario_0.tif.aux.xml  # Auxiliary metadata
├── Longport_Flood_Depth_Scenario_1.tif
├── Longport_Flood_Depth_Scenario_1.tfw
└── ...
```

#### Usage Example
```matlab
% Basic usage - process all scenarios
run('3_FloodModel_to_DamageModel.m');

% Custom output location
output_folder = './my_custom_output';
run('3_FloodModel_to_DamageModel.m');

% Process subset of scenarios
scenario_folders = {'1', '2'};  % Only low emission scenarios
run('3_FloodModel_to_DamageModel.m');
```

#### FAST Integration

**Step 1**: Copy GeoTIFF files to FAST directory
```bash
# Copy all generated files to FAST Rasters folder
cp FAST_Rasters/* /path/to/FAST/Rasters/
```

**Step 2**: Import in FAST
1. Open FEMA FAST application
2. Navigate to: Analysis → Import Hazard Data
3. Select GeoTIFF files from Rasters folder
4. Verify spatial reference (NAD83 UTM Zone 18N)
5. Confirm units are in feet

**Step 3**: Run Damage Assessment
1. Load National Structure Inventory (NSI)
2. Select hazard scenarios
3. Configure depth-damage functions
4. Execute damage calculations
5. Export results for cost-benefit analysis

#### Validation Checks

```matlab
% Verify GeoTIFF creation
info = geotiffinfo('FAST_Rasters/Longport_Flood_Depth_Scenario_0.tif');
fprintf('Spatial Reference: %s\n', info.GCS.Name);
fprintf('Coordinate System: %s\n', info.PCS.Name);
fprintf('Units: %s\n', info.PCS.Unit);

% Check data range
[flood_data, R] = geotiffread('FAST_Rasters/Longport_Flood_Depth_Scenario_0.tif');
valid_data = flood_data(flood_data ~= nodata_value);
fprintf('Flood depth range: %.2f to %.2f feet\n', ...
        min(valid_data), max(valid_data));
```

#### Troubleshooting

**Issue**: GeoTIFF not recognized in FAST
```matlab
% Solution 1: Verify projection
% Ensure using NAD83 UTM Zone 18N, not WGS84

% Solution 2: Check for world file
% World file must have same name as GeoTIFF with .tfw extension

% Solution 3: Verify units
% FAST requires feet, not meters
% Check meters_to_feet = 3.28084
```

**Issue**: NoData values displayed as valid data
```matlab
% Solution: Verify aux.xml file exists
% NoData value must match FAST requirements
% Check: nodata_value = -3.4028230607370965e+38
```

**Issue**: Spatial misalignment in FAST
```matlab
% Solution: Verify coordinate system
% Use GCS: North American 1983
% Use PCS: NAD83 UTM Zone 18N
% Check ModelTiepointTag values in GeoTIFF
```

---

## XBeach Parameter Template (`params.txt`)

The `params.txt` file serves as the template for XBeach model configuration. The `1_WaveModelCreation.m` script reads this template and modifies specific parameters for each scenario.

### Key Parameters

#### Physical Processes
```
swave       = 0          # Short wave action disabled (non-hydrostatic mode)
nonh        = 1          # Non-hydrostatic mode enabled
sedtrans    = 0          # Sediment transport disabled
morphology  = 0          # Morphological updating disabled
vegetation  = 1          # Vegetation effects enabled
wavemodel   = nonh       # Use non-hydrostatic wave model
```

#### Vegetation Configuration
```
veggiefile    = vegetation.txt      # Vegetation characteristics file
veggiemapfile = vegrigidmap.txt     # Spatial vegetation distribution
```

#### Numerical Parameters
```
eps         = 0.005      # Wave breaking parameter
CFL         = 0.9        # Courant number for stability
g           = 9.81       # Gravitational acceleration (m/s²)
rho         = 1000       # Water density (kg/m³)
depthscale  = 1          # Depth scaling factor
```

#### Grid Configuration
```
posdwn      = -1         # Positive direction is up
depfile     = bed.txt    # Bathymetry file
vardx       = 1          # Variable grid spacing enabled
nx          = 1658       # Number of grid points (updated per scenario)
ny          = 0          # 1D model (cross-shore only)
xfile       = x.txt      # X-coordinates file
yfile       = y.txt      # Y-coordinates file
```

#### Bed Friction
```
bedfriction = manning            # Use Manning's roughness
bedfricfile = bedfricfile.txt   # Spatially variable Manning's n
```

#### Wave Breaking
```
maxbrsteep  = 0.65      # Maximum wave steepness for breaking
```

#### Boundary Conditions
```
wbctype     = jonstable  # JONSWAP spectrum from table
random      = 0          # Deterministic waves
bcfile      = jonswap_table.txt   # Wave spectrum file
rt          = 1200       # Duration of wave spectrum (s)
dtbc        = 1          # Time step for boundary conditions (s)

left        = wall       # Left boundary (wall)
right       = wall       # Right boundary (wall)
front       = nonh_1d    # Front boundary (non-hydrostatic)
back        = abs_1d     # Back boundary (absorbing)

zs0file     = stormtide.txt  # Water level time series
tideloc     = 2              # Water level specified at back boundary
```

#### Output Configuration
```
npoints     = 7          # Number of output stations
# Station locations (x, y coordinates):
0.00 0.       # Station 1: Offshore
3743.64 0.    # Station 2: Vegetation start
3772.00 0.    # Station 3: Near seawall
3773.00 0.    # Station 4: At seawall
3774.00 0.    # Station 5: Behind seawall
3775.00 0.    # Station 6: Urban area
3780.00 0.    # Station 7: Far inland

npointvar    = 4         # Variables at stations
zs                       # Water surface elevation
zb                       # Bed level
x                        # X-coordinate
qx                       # Discharge per unit width

outputformat = fortran   # Output file format
tstart       = 0.0       # Start time (s)
tstop        = 345600    # Stop time (s) - 4 days
tintg        = 1         # Output interval (s)
nglobalvar   = 1         # Number of global output variables
zs                       # Water surface elevation
```

### Parameters Modified by Script

The `1_WaveModelCreation.m` script automatically updates these parameters:

1. **vegetation** - 0 or 1 (on/off)
2. **CFL** - Courant number
3. **eps** - Wave breaking parameter
4. **nx** - Number of grid points (scenario-dependent)
5. **npoints** - Updated with key locations (seawall, vegetation)

### Customization Guide

To modify the template for your application:

```matlab
% Example: Change output frequency
% In params.txt, modify:
tintg = 10    % Output every 10 seconds instead of 1

% Example: Add more output variables
nglobalvar = 3
zs
H     % Wave height
u     % Velocity

% Example: Change wave breaking parameter
maxbrsteep = 0.70  % Allow steeper waves
```

---

## Complete Workflow

### Prerequisites

**Software Requirements:**
- MATLAB R2019b or later
- XBeach (open-source, https://oss.deltares.nl/web/xbeach/)
- SFINCS (https://sfincs.readthedocs.io/)
- FEMA FAST (https://github.com/nhrap-hazus/FAST)

**MATLAB Toolboxes:**
- Statistics and Machine Learning Toolbox
- Signal Processing Toolbox
- Mapping Toolbox
- Image Processing Toolbox

**Data Requirements:**
- Beach profile data
- Hurricane Sandy wave and water level data
- Building inventory (National Structure Inventory)
- High-resolution elevation data (CoNED)
- Land cover data (NOAA C-CAP)

### Step-by-Step Execution

#### Step 1: Generate XBeach Input Files
```matlab
% Navigate to processing codes directory
cd processing_codes/

% Run wave model creation script
run('1_WaveModelCreation.m');

% Expected output: 7 scenario folders created
% 00_Sandy_3_3_2025/ through 06_Sandy_3_3_2025/
```

**Verification:**
```matlab
% Check that all files were created
for i = 0:6
    folder = sprintf('%02d_Sandy_3_3_2025', i);
    assert(exist(fullfile(folder, 'bed.txt'), 'file') > 0, ...
           'bed.txt not found in %s', folder);
    fprintf('Scenario %d: Files created successfully\n', i);
end
```

#### Step 2: Run XBeach Simulations
```bash
# For each scenario, run XBeach
cd 00_Sandy_3_3_2025
xbeach

# Monitor simulation progress
tail -f XBlog.txt

# Check for successful completion
# Look for "Simulation finished" in XBlog.txt

# Repeat for all scenarios
cd ../01_Sandy_3_3_2025
xbeach
# ... continue for scenarios 02-06
```

**Parallel Execution (if available):**
```bash
# Create a batch script to run all scenarios
#!/bin/bash
for i in {00..06}; do
    cd ${i}_Sandy_3_3_2025
    xbeach &
    cd ..
done
wait
```

**Expected Runtime:**
- Control scenarios: ~2-4 hours each
- Hybrid scenarios: ~3-6 hours each
- Total: ~25-35 hours on standard workstation

#### Step 3: Extract Overtopping Results
```matlab
% Collect XBeach outputs into summary file
% (Assuming you have a script to do this, or manual extraction)

% Process overtopping data for SFINCS
run('2_WaveModel_to_FloodModel.m');

% Verify output files created
assert(exist('extracted_data/scenario_0_for_sfincs.txt', 'file') > 0, ...
       'SFINCS input files not created');
```

**Quality Control:**
```matlab
% Check smoothing quality
load('extracted_data/scenario_2_plot_data.mat');
figure;
subplot(2,1,1);
plot(plot_data.orig_vector, plot_data.orig_series);
title('Raw XBeach Output');
subplot(2,1,2);
plot(plot_data.times, plot_data.values);
title('Processed for SFINCS');
```

#### Step 4: Setup and Run SFINCS
```bash
# Copy processed overtopping files to SFINCS directories
for i in {0..6}; do
    cp extracted_data/scenario_${i}_for_sfincs.txt \
       sfincs_scenarios/${i}/sfincs_src.txt
done

# Run SFINCS for each scenario
cd sfincs_scenarios/0
sfincs

# Monitor progress
tail -f sfincs.log

# Repeat for all scenarios
```

**SFINCS Configuration Checklist:**
- Grid resolution: 1.5 m
- Time step: Adaptive (CFL-based)
- Infiltration: Calibrated rates for different land covers
- Manning roughness: Spatially variable
- Boundary conditions: Processed overtopping time series

**Expected Runtime:**
- ~15-30 minutes per scenario
- Total: ~2-4 hours for all scenarios

#### Step 5: Convert to FAST Format
```matlab
% Convert SFINCS outputs to GeoTIFF
run('3_FloodModel_to_DamageModel.m');

% Verify GeoTIFF creation
files = dir('FAST_Rasters/*.tif');
fprintf('%d GeoTIFF files created\n', length(files));
```

**Validation:**
```matlab
% Verify spatial reference
info = geotiffinfo('FAST_Rasters/Longport_Flood_Depth_Scenario_0.tif');
assert(strcmp(info.PCS.PCSCitation, 'NAD_1983_UTM_Zone_18N'), ...
       'Incorrect projection');
fprintf('Spatial reference verified: %s\n', info.PCS.PCSCitation);
```

#### Step 6: Run FAST Damage Assessment
```
1. Open FEMA FAST application
2. Create new project: "Longport_Hurricane_Sandy_Analysis"
3. Import hazard data:
   - Load GeoTIFF files from FAST_Rasters/
   - Verify spatial alignment with NSI data
4. Load building inventory:
   - Import National Structure Inventory (NSI)
   - Filter for Longport study area
5. Run analysis:
   - Select all scenarios
   - Execute damage calculations
   - Export results to CSV
6. Cost-Benefit Analysis:
   - Calculate avoided damages
   - Compare with implementation costs
   - Compute benefit-cost ratios
```

#### Step 7: Post-Processing and Visualization
```matlab
% Load FAST results
fast_results = readtable('fast_outputs/damage_summary.csv');

% Calculate avoided damages
control_damage = fast_results.TotalDamage(fast_results.Scenario == 0);
for i = 1:6
    scenario_damage = fast_results.TotalDamage(fast_results.Scenario == i);
    avoided_damage(i) = control_damage - scenario_damage;
    fprintf('Scenario %d avoided damage: $%.2f M\n', i, avoided_damage(i)/1e6);
end

% Create visualization
figure;
bar(avoided_damage/1e6);
xlabel('Scenario');
ylabel('Avoided Damage ($ Million)');
title('Economic Benefits of Hybrid Systems');
```

---

## Scenario Descriptions

### Control Scenarios (No Nature-Based Solutions)

#### Case 0 (CS) - Baseline
- **Description**: 2012 Hurricane Sandy conditions with existing 0.9m seawall
- **Purpose**: Validation baseline and reference for damage calculations
- **Key Parameters**:
  - Seawall height: 0.9 m
  - No vegetation
  - Mean sea level: Historical (2012)

#### Case 1 (CS+SLR1) - Low Emission Control
- **Description**: Control scenario with low emission sea level rise
- **Purpose**: Assess impacts of moderate climate change without adaptation
- **Key Parameters**:
  - Seawall height: 0.9 m
  - No vegetation
  - Sea level rise: +0.814 m (SSP2-4.5)
  - Time horizon: End of 21st century

#### Case 2 (CS+SLR2) - High Emission Control
- **Description**: Control scenario with high emission sea level rise
- **Purpose**: Worst-case scenario without adaptation measures
- **Key Parameters**:
  - Seawall height: 0.9 m
  - No vegetation
  - Sea level rise: +1.036 m (SSP5-8.5)
  - Time horizon: End of 21st century

### Hybrid Design I Scenarios

Design I emphasizes structural enhancement with moderate vegetation support.

#### Case 3 (DI+SLR1)
- **Description**: Taller seawall with moderate vegetation under low emission SLR
- **Design Philosophy**: Higher structural component for broad protection
- **Key Parameters**:
  - Seawall height: 1.2 m (+33% from baseline)
  - Vegetation area: 25 m²/m (moderate coverage)
  - Vegetation density: 20 stems/m² (sparse)
  - Vegetation species: Juncus roemerianus (black needlerush)
  - Sea level rise: +0.814 m (SSP2-4.5)

#### Case 4 (DI+SLR2)
- **Description**: Taller seawall with moderate vegetation under high emission SLR
- **Purpose**: Test Design I resilience under extreme conditions
- **Key Parameters**:
  - Seawall height: 1.2 m
  - Vegetation area: 25 m²/m
  - Vegetation density: 20 stems/m²
  - Sea level rise: +1.036 m (SSP5-8.5)

### Hybrid Design II Scenarios

Design II prioritizes extensive vegetation with intermediate structural support.

#### Case 5 (DII+SLR1)
- **Description**: Intermediate seawall with extensive vegetation under low emission SLR
- **Design Philosophy**: Nature-based emphasis for peak mitigation
- **Key Parameters**:
  - Seawall height: 1.0 m (+11% from baseline)
  - Vegetation area: 36 m²/m (extensive coverage)
  - Vegetation density: 300 stems/m² (dense)
  - Vegetation species: Juncus roemerianus
  - Sea level rise: +0.814 m (SSP2-4.5)

#### Case 6 (DII+SLR2)
- **Description**: Intermediate seawall with extensive vegetation under high emission SLR
- **Purpose**: Test vegetation effectiveness under extreme sea level rise
- **Key Parameters**:
  - Seawall height: 1.0 m
  - Vegetation area: 36 m²/m
  - Vegetation density: 300 stems/m²
  - Sea level rise: +1.036 m (SSP5-8.5)

---

## Key Findings

### Wave Overtopping Mitigation

**Control Scenario Vulnerability:**
- Baseline overtopping: 433.7 m³/m
- With SLR1: 5753.3 m³/m (+1226% increase)
- With SLR2: 10476.2 m³/m (+2315% increase)

**Hybrid System Performance:**

*Design I (Taller Seawall + Moderate Vegetation):*
- SLR1: 32% reduction vs. control
- SLR2: 36% reduction vs. control
- Total overtopping: 3893.8 m³/m (SLR1), 6745.1 m³/m (SLR2)

*Design II (Intermediate Seawall + Dense Vegetation):*
- SLR1: 88% reduction vs. control
- SLR2: 86% reduction vs. control
- Total overtopping: 690.0 m³/m (SLR1), 1424.5 m³/m (SLR2)

**Key Insight**: Dense vegetation (300 stems/m²) provides superior protection compared to increased structural height alone, achieving nearly 3x better performance than Design I.

### Urban Flood Characteristics

**Flood Extent:**
- Baseline: 63.7% of study area flooded
- SLR1 Control: 93.9% flooded
- SLR2 Control: 96.8% flooded

**Flood Depth Reduction:**

*Design I:*
- Significant reduction coverage: 85.8% (SLR1), 93.0% (SLR2) of domain
- Average reduction: 0.2-0.4 m
- Pattern: Broad, uniform reduction across study area

*Design II:*
- Significant reduction coverage: 73.4% (SLR1), 85.8% (SLR2) of domain
- Peak reduction: Up to 1.2 m in vulnerable areas
- Pattern: Concentrated in critical low-lying zones

**Flood Duration:**

*Control Scenarios:*
- Baseline: 7.3 hours average
- SLR1: 16.3 hours average (+123%)
- SLR2: 20.0 hours average (+174%)

*Design I Reductions:*
- SLR1: 2.0 hours reduction
- SLR2: 2.3 hours reduction

*Design II Reductions:*
- SLR1: 8.5 hours reduction (-52%)
- SLR2: 10.3 hours reduction (-52%)

**Critical Infrastructure Impacts:**

| Facility | Control SLR2 Depth | DI+SLR2 Depth | DII+SLR2 Depth | DII Reduction |
|----------|-------------------|---------------|----------------|---------------|
| Margate PD | 1.56 m | 1.27 m | 0.91 m | 46.9% |
| Margate FD1 | 0.48 m | 0.34 m | 0.00 m | 100% |
| Margate FD2 | 1.17 m | 0.94 m | 0.48 m | 49.3% |
| Longport PD | 1.27 m | 1.00 m | 0.77 m | 54.0% |
| Longport VFD | 1.01 m | 0.77 m | 0.33 m | 56.3% |

### Economic Analysis

**Damage Estimates (Present Value in 2022 $):**

| Scenario | Structural Damage | Contents Damage | Total Damage | Future Value (2100 $) |
|----------|------------------|-----------------|--------------|----------------------|
| CS (Baseline) | $2.38M | $2.36M | $4.74M | $13.56M |
| CS+SLR1 | $7.03M | $7.96M | $15.0M | $42.81M |
| CS+SLR2 | $10.08M | $11.99M | $22.1M | $63.03M |
| DI+SLR1 | $5.17M | $5.98M | $11.2M | $31.84M |
| DI+SLR2 | $7.39M | $8.34M | $15.7M | $44.95M |
| DII+SLR1 | $2.28M | $2.24M | $4.5M | $12.90M |
| DII+SLR2 | $3.22M | $3.47M | $6.7M | $19.10M |

**Cost-Benefit Analysis:**

| Design | Scenario | Implementation Cost (PV) | Avoided Damage (PV) | BCR |
|--------|----------|-------------------------|---------------------|-----|
| Design I | SLR1 | $4.51M | $3.84M | 0.85 |
| Design I | SLR2 | $4.51M | $6.33M | **1.40** |
| Design II | SLR1 | $10.28M | $10.47M | **1.02** |
| Design II | SLR2 | $10.28M | $15.38M | **1.49** |

**Key Economic Insights:**
1. Economic viability increases with climate change severity
2. BCR > 1.0 achieved for both designs under high emission scenarios
3. Design II shows superior long-term value despite higher initial cost
4. Not included: Ecosystem service co-benefits (estimated +15-40% value)

---

## Data Format and Usage

### MATLAB Files (.mat)

#### Case Results Structure
```matlab
% Load case results
load('case_00_results.mat');

% Structure contains:
results.overtopping.discharge   % Time series (m³/s/m)
results.overtopping.time        % Time vector (seconds)
results.overtopping.stats       % Statistical measures
    .max                        % Maximum discharge
    .mean                       % Average discharge
    .total_volume              % Cumulative volume (m³/m)
results.profile                 % Beach/seawall profile
    .x                          % X-coordinates
    .z                          % Elevations
results.vegetation              % Vegetation parameters
    .area                       % Coverage area (m²/m)
    .density                    % Stem density (stems/m²)
    .height                     % Vegetation height (m)
```

#### Usage Example
```matlab
% Compare peak overtopping across scenarios
scenarios = 0:6;
peak_discharge = zeros(size(scenarios));

for i = scenarios
    filename = sprintf('case_%02d_results.mat', i);
    data = load(filename);
    peak_discharge(i+1) = data.results.overtopping.stats.max;
end

figure;
bar(peak_discharge);
xlabel('Scenario');
ylabel('Peak Discharge (m³/s/m)');
title('Peak Overtopping Comparison');
```

### NetCDF Files (.nc)

#### SFINCS Output Variables
```python
import xarray as xr

# Open SFINCS output
ds = xr.open_dataset('SFINCS_case_00.nc')

# Available variables:
# - zs: Water surface elevation (m) [time, y, x]
# - zsmax: Maximum water surface elevation (m) [y, x]
# - hmax: Maximum water depth (m) [y, x]
# - tmax: Time of maximum depth (seconds) [y, x]
# - vmax: Maximum velocity (m/s) [y, x]
# - x: X-coordinates (m) [x]
# - y: Y-coordinates (m) [y]
# - time: Time steps (seconds) [time]
```

#### Usage Example
```python
# Extract and plot maximum flood depth
import matplotlib.pyplot as plt

hmax = ds.hmax.values
x = ds.x.values
y = ds.y.values

# Create flood map
fig, ax = plt.subplots(figsize=(12, 8))
im = ax.pcolormesh(x, y, hmax, cmap='Blues', vmin=0, vmax=2)
plt.colorbar(im, label='Maximum Flood Depth (m)')
ax.set_xlabel('Easting (m)')
ax.set_ylabel('Northing (m)')
ax.set_title('Scenario 0: Maximum Flood Extent')
plt.tight_layout()
plt.savefig('flood_extent.png', dpi=300)
```

### GeoTIFF Files (.tif)

#### Raster Properties
- **Format**: GeoTIFF (Float32)
- **Projection**: NAD83 UTM Zone 18N (EPSG:26918)
- **Units**: Feet (for FAST compatibility)
- **Resolution**: 1.5 m × 1.5 m
- **NoData Value**: -3.4028230607370965e+38
- **Extent**: Longport study area (~2.2 km²)

#### Usage Example
```matlab
% Read GeoTIFF
[flood_depth, R] = geotiffread('FAST_Rasters/Longport_Flood_Depth_Scenario_0.tif');

% Convert NoData to NaN for visualization
nodata = -3.4028230607370965e+38;
flood_depth(flood_depth == nodata) = NaN;

% Create map
figure;
mapshow(flood_depth, R, 'DisplayType', 'surface');
colormap(jet);
colorbar;
title('Flood Depth (feet)');
```

---

## Model Configuration Details

### XBeach Configuration

#### Computational Grid
```
Offshore region:    10 m spacing (x < 3700 m)
Transition zone:    2-10 m spacing (3700-3760 m)
Nearshore region:   0.2-2 m spacing (3760-3772 m)
Seawall vicinity:   0.1-0.2 m spacing (3772-3776 m)
Urban area:         0.2-1 m spacing (x > 3776 m)

Total points:       ~1658 (scenario-dependent)
Cross-shore extent: ~3800 m
```

#### Wave Breaking Parameters
```matlab
% Breaking criterion
maxbrsteep = 0.65          % Maximum H/h ratio

% Dissipation parameters
breakviscfac = 1.5         % Breaking-induced viscosity factor
gamma = 0.55               % Breaking parameter (default)
```

#### Vegetation Implementation
```matlab
% Bulk drag coefficient (Tanino & Nepf formula)
C_D = 2 * (α₀/R_p + α₁)

% Where:
% R_p = u*b_v/ν (Plant Reynolds number)
% α₀, α₁ = empirical coefficients
% u = velocity, b_v = stem diameter, ν = kinematic viscosity

% Calibrated for Juncus roemerianus:
% Stem diameter: 0.005 m
% Height: 1.0 m
% Drag coefficient: 0.8-1.5 (velocity-dependent)
```

### SFINCS Configuration

#### Computational Grid
```
Grid type:          Regular Cartesian
Resolution:         1.5 m × 1.5 m
Total cells:        1,300,000
Active cells:       570,000 (excluding buildings)
Study domain:       2.2 km²
Coordinate system:  NAD83 UTM Zone 18N
```

#### Boundary Conditions
```
East (Ocean):       Discharge (from XBeach overtopping)
West (Back Bay):    Outflow (zero gradient)
North (Margate):    Outflow (zero gradient)
South (Inlet):      Outflow (zero gradient)
```

#### Infiltration Rates (Calibrated)
```
Land Cover Type          Manning's n    Infiltration Rate
-------------------------------------------------------------
Open water              0.017 s/m^(1/3)    0 mm/hr
Bare soil               0.030 s/m^(1/3)    5 mm/hr
Vegetated land          0.035 s/m^(1/3)    15 mm/hr
Roads/paved surfaces    0.022 s/m^(1/3)    15 mm/hr
Buildings               N/A                0 mm/hr (obstruction)
```

#### Time Stepping
```
CFL condition:      CFL < 0.7
Typical Δt:         0.5-2.0 seconds (adaptive)
Simulation period:  96 hours (Hurricane Sandy duration)
Output interval:    300 seconds (5 minutes)
```

### FAST Configuration

#### Depth-Damage Functions
```
Building Type       Foundation Type    Occupancy Class
----------------------------------------------------------
1-story wood        Slab-on-grade      Residential
2-story wood        Crawlspace         Residential
Split-level         Basement           Residential
Commercial          Various            Commercial
Public              Various            Public/Institutional
```

#### Damage Categories
```
Structural Damage:
- Foundation damage
- Wall damage
- Floor system damage
- Roof damage

Contents Damage:
- Finished basement
- Ground floor contents
- Upper floor contents (if applicable)
```

---

## Validation and Quality Control

### XBeach Validation

**Method**: Comparison with laboratory experiments and field data

**Validation Metrics**:
- R² = 0.83 for wave runup prediction
- 59% of simulations within 20% error
- Validated across 63 different wave conditions

**Sources**:
- Small-scale laboratory (Amini & Marsooli, 2023)
- Large-scale wave flume
- Field observations from previous storms

### SFINCS Validation

**Method**: Comparison with USGS High Water Marks from Hurricane Sandy

**Measurement Stations**:
- NJATL07248: Observed = 2.56 m, Simulated = 2.56 m (0.0% error)
- NJATL07247: Observed = 2.53 m, Simulated = 2.57 m (1.6% error)

**Calibration Parameters**:
- Infiltration rates: Optimized for minimum RMSE
- Manning roughness: Based on C-CAP land cover
- Best RMSE: 0.079 m (3.1% relative error)

### Quality Control Procedures

#### Data Preprocessing
```matlab
% Volume conservation check
function checkVolumeConservation(original, processed)
    vol_orig = sum(original) * dt;
    vol_proc = sum(processed) * dt;
    error = abs(vol_proc - vol_orig) / vol_orig * 100;
    
    if error > 5.0
        warning('Volume conservation error: %.2f%% (threshold: 5%%)', error);
    else
        fprintf('Volume conserved within %.2f%%\n', error);
    end
end
```

#### Spatial Consistency
```python
# Check for spatial discontinuities
def check_spatial_consistency(flood_depth, threshold=0.5):
    """Check for unrealistic depth gradients"""
    dx = np.diff(flood_depth, axis=0)
    dy = np.diff(flood_depth, axis=1)
    
    max_gradient_x = np.max(np.abs(dx))
    max_gradient_y = np.max(np.abs(dy))
    
    if max_gradient_x > threshold or max_gradient_y > threshold:
        print(f'Warning: Large gradient detected')
        print(f'Max X gradient: {max_gradient_x:.2f} m')
        print(f'Max Y gradient: {max_gradient_y:.2f} m')
```

---

## Requirements and Dependencies

### Software Requirements

**MATLAB** (R2019b or later)
```
Required Toolboxes:
- Statistics and Machine Learning Toolbox
- Signal Processing Toolbox  
- Mapping Toolbox
- Image Processing Toolbox

Optional (for advanced analysis):
- Parallel Computing Toolbox
- Curve Fitting Toolbox
```

**XBeach** (Latest stable version)
```bash
# Installation (Linux/Mac)
git clone https://github.com/openearth/xbeach.git
cd xbeach
./autogen.sh
./configure
make
sudo make install
```

**SFINCS** (v2.0 or later)
```bash
# Installation
git clone https://github.com/Deltares/SFINCS.git
cd SFINCS
mkdir build && cd build
cmake ..
make
sudo make install
```

**FEMA FAST** (Latest version)
```bash
# Installation (Windows)
# Download from: https://github.com/nhrap-hazus/FAST
# Install following FEMA guidelines
```

### Python Dependencies (Optional)

For advanced analysis and visualization:

```bash
pip install xarray netcdf4 numpy matplotlib cartopy geopandas rasterio
```

```python
# requirements.txt
xarray>=2022.3.0
netcdf4>=1.5.8
numpy>=1.22.0
matplotlib>=3.5.0
cartopy>=0.20.0
geopandas>=0.11.0
rasterio>=1.3.0
pandas>=1.4.0
scipy>=1.8.0
```

### System Requirements

**Minimum:**
- CPU: Intel i5 or equivalent (4 cores)
- RAM: 16 GB
- Storage: 50 GB free space
- OS: Windows 10, Linux (Ubuntu 20.04+), macOS 11+

**Recommended:**
- CPU: Intel i7/i9 or AMD Ryzen 7/9 (8+ cores)
- RAM: 32 GB
- Storage: 100 GB SSD
- GPU: Not required but beneficial for visualization

**For parallel processing:**
- CPU: 16+ cores
- RAM: 64 GB
- Network storage for large datasets

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: XBeach Simulation Crashes

**Symptom**: XBeach stops with "NaN detected" error

**Solutions**:
```matlab
% 1. Check CFL condition
% In params.txt:
CFL = 0.7  % Reduce from 0.9

% 2. Check grid resolution
% Ensure smooth transitions:
max_grid_ratio = 1.2  % Maximum spacing ratio

% 3. Check bathymetry
% Remove unrealistic jumps in bed elevation
```

#### Issue 2: SFINCS Instability

**Symptom**: Unrealistic flood depths or model divergence

**Solutions**:
```matlab
% 1. Check overtopping input
% Verify no negative values:
smoothed_data = max(smoothed_data, 0);

% 2. Adjust time step
% In SFINCS input file:
dt = 0.5  % Reduce from 1.0

% 3. Check infiltration rates
% Ensure realistic values (0-30 mm/hr)
```

#### Issue 3: GeoTIFF Not Loading in FAST

**Symptom**: FAST cannot read flood depth rasters

**Solutions**:
```matlab
% 1. Verify projection
info = geotiffinfo('flood_depth.tif');
assert(contains(info.PCS.PCSCitation, 'NAD_1983_UTM_Zone_18N'));

% 2. Check units (must be feet)
% Verify conversion factor: 3.28084

% 3. Ensure auxiliary files exist
% Required files:
% - flood_depth.tif
% - flood_depth.tfw
% - flood_depth.prj
% - flood_depth.tif.aux.xml
```

#### Issue 4: Memory Issues

**Symptom**: "Out of memory" errors during processing

**Solutions**:
```matlab
% 1. Process scenarios sequentially
process_scenarios = 0;  % One at a time
run('2_WaveModel_to_FloodModel.m');

% 2. Clear workspace regularly
clear all; close all; clc;

% 3. Reduce output frequency
% In params.txt:
tintg = 10  % Output every 10s instead of 1s
```

#### Issue 5: Smoothing Removes Too Much Detail

**Symptom**: Processed overtopping data looks over-smoothed

**Solutions**:
```matlab
% Adjust smoothing parameters
smoothing_window_minutes = 10.0;  % Reduce from 20.0

% Or modify filter order
poly_order = 2;  % Reduce from 3

% Or disable second-pass smoothing
% Comment out Savitzky-Golay filter section
```

---

## Citation and Publication

### Citation Format

If you use this framework, data, or code in your research, please cite:

```bibtex
@article{amini2025hybrid,
  title={Integrated Hydrodynamic-Economic Modeling Framework for Vegetation-fronted Seawalls: Application to Flood-Prone Barrier Island Communities},
  author={Amini, Erfan and Marsooli, Reza},
  journal={Environmental Modelling and Software},
  year={2025},
  status={In Review},
  doi={pending}
}
```

### Related Publications

```bibtex
@article{amini2023multiscale,
  title={Multi-scale calibration of a non-hydrostatic model for wave runup simulation},
  author={Amini, Erfan and Marsooli, Reza},
  journal={Ocean Engineering},
  volume={285},
  pages={115392},
  year={2023},
  doi={10.1016/j.oceaneng.2023.115392}
}

@article{amini2024vegetation,
  title={Multi-faceted Methodology for Coastal Vegetation Drag Coefficient Calibration: Implications for Wave Height Attenuation},
  author={Amini, Erfan and Marsooli, Reza and Neshat, Mehdi},
  journal={Ocean Engineering},
  volume={302},
  pages={102391},
  year={2024},
  doi={10.1016/j.oceaneng.2024.102391}
}

@article{amini2025characterizing,
  title={Characterizing vegetation effects on wave mitigation performance of resilient hybrid vegetation-seawall systems},
  author={Amini, Erfan and Marsooli, Reza and Ayyub, Bilal M},
  journal={Environmental Research Communications},
  volume={7},
  number={3},
  pages={035014},
  year={2025},
  doi={10.1088/2515-7620/adbc4d}
}
```

---

## Contact Information

For questions about the data, methodology, or code implementation:

**Erfan Amini, Ph.D.**
- Email: ea3246@columbia.edu
- Affiliation: Center for Climate Systems Research, Climate School, Columbia University
- Location: New York City, New York, USA

**Reza Marsooli, Ph.D.**
- Email: rmarsooli@stevens.edu
- Affiliation: Department of Civil, Environmental, and Ocean Engineering, Stevens Institute of Technology
- Location: Hoboken, New Jersey, USA

---

## License

This dataset and associated code are made available for research and educational purposes. Please contact the authors for commercial use or redistribution.

---

## Acknowledgments

This research was conducted using:

- **XBeach** non-hydrostatic wave modeling software (open-source)
- **SFINCS** coastal flood modeling framework developed by Deltares®
- **USGS High Water Mark** data from Hurricane Sandy
- **NOAA C-CAP** High-Resolution Land Cover data
- **FEMA Flood Assessment Structure Tool (FAST)**
- **New Jersey Beach Profile Network (NJBPN)** database
- **Coastal National Elevation Database (CoNED)** from USGS
- **National Structure Inventory (NSI)** from US Army Corps of Engineers

Special thanks to:
- Stevens Institute of Technology for computational resources
- Columbia University Climate School for research support
- The open-source scientific computing community

---

## Version History

- **v2.0.0** (February 2025): Complete framework with all three processing codes
- **v1.0.0** (Initial Release): Basic model outputs and results

---

## Future Development

Planned enhancements:
- Automated parallelization scripts for XBeach and SFINCS
- Python versions of processing codes
- Interactive visualization dashboard
- Integration with additional damage assessment tools
- Expansion to other coastal communities

---

**Repository Status**: Active  
**Last Updated**: February 2025  
**Maintainer**: Erfan Amini (ea3246@columbia.edu)

---

*For the latest updates and additional resources, please visit the project repository or contact the authors directly.*
