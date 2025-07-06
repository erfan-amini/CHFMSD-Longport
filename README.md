# CHFMSD-Longport
(Coastal Hybrid Flood Mitigation System Dataset for Longport, NJ, USA)

## Overview

This repository contains the computational results and analysis codes for a comprehensive study evaluating the effectiveness of hybrid vegetation-seawall systems in mitigating coastal flooding under present and future sea level rise scenarios. The research focuses on Longport, New Jersey, using Hurricane Sandy as a test case to assess the performance of nature-based solutions integrated with traditional coastal defense structures.

## Research Background

As coastal communities face increasing threats from sea level rise and extreme weather events, traditional coastal defense structures like seawalls are becoming insufficient on their own. This study investigates how integrating vegetation with seawalls can enhance coastal resilience while providing economic benefits through a comprehensive cost-benefit analysis.

### Study Methodology

The research employs an integrated modeling approach combining:
- **XBeach Non-Hydrostatic (XBNH)** model for wave propagation, transformation, and overtopping simulation
- **SFINCS (Super-Fast Inundation of CoastS)** model for street-scale urban flooding simulation
- **FEMA's Flood Assessment Structure Tool (FAST)** for economic damage assessment

## Repository Structure

### Results Files

#### Individual Case Results
```
case_00_results.mat  # Control Scenario (CS) - Baseline 2012 conditions
case_01_results.mat  # CS + SLR1 (Low emission scenario SSP2-4.5)
case_02_results.mat  # CS + SLR2 (High emission scenario SSP5-8.5)
case_03_results.mat  # Design I + SLR1 (Hybrid design with taller seawall)
case_04_results.mat  # Design I + SLR2 (Hybrid design with taller seawall)
case_05_results.mat  # Design II + SLR1 (Hybrid design with extensive vegetation)
case_06_results.mat  # Design II + SLR2 (Hybrid design with extensive vegetation)
```

#### Summary Results
```
overtopping_summary.mat  # Consolidated overtopping analysis across all scenarios
```

#### SFINCS Model Outputs
```
SFINCS_case_00.nc  # Urban flooding simulation for baseline scenario
SFINCS_case_01.nc  # Urban flooding simulation for CS + SLR1
SFINCS_case_02.nc  # Urban flooding simulation for CS + SLR2
SFINCS_case_03.nc  # Urban flooding simulation for Design I + SLR1
SFINCS_case_04.nc  # Urban flooding simulation for Design I + SLR2
SFINCS_case_05.nc  # Urban flooding simulation for Design II + SLR1
SFINCS_case_06.nc  # Urban flooding simulation for Design II + SLR2
```

## Scenario Descriptions

### Control Scenarios (No Nature-based Solutions)
- **Case 0 (CS)**: Baseline conditions representing 2012 Hurricane Sandy with existing 0.9m seawall
- **Case 1 (CS+SLR1)**: Control scenario with low emission sea level rise projection (SSP2-4.5: +0.814m)
- **Case 2 (CS+SLR2)**: Control scenario with high emission sea level rise projection (SSP5-8.5: +1.036m)

### Hybrid Design I Scenarios
- **Case 3 (DI+SLR1)**: Enhanced seawall (1.2m height) with moderate vegetation (25 m²/m area, 20 stems/m²) under low emission SLR
- **Case 4 (DI+SLR2)**: Enhanced seawall (1.2m height) with moderate vegetation (25 m²/m area, 20 stems/m²) under high emission SLR

### Hybrid Design II Scenarios  
- **Case 5 (DII+SLR1)**: Intermediate seawall (1.0m height) with extensive vegetation (36 m²/m area, 300 stems/m²) under low emission SLR
- **Case 6 (DII+SLR2)**: Intermediate seawall (1.0m height) with extensive vegetation (36 m²/m area, 300 stems/m²) under high emission SLR

## Key Findings

### Wave Overtopping Mitigation
- **Control scenarios** show dramatic increases in overtopping volumes under sea level rise (10x to 20x increase)
- **Design I** achieves 32-36% reduction in overtopping compared to equivalent control scenarios
- **Design II** demonstrates exceptional performance with 86-88% reduction in overtopping volumes
- Extensive vegetation proves more effective than simply increasing seawall height

### Flood Characteristics
- Hybrid designs significantly reduce flood extent, depth, and duration in urban areas
- Design II provides critical additional time for emergency response and evacuation
- Dense vegetation effectively dissipates wave energy and delays overtopping onset

### Economic Analysis
- Both hybrid designs show positive benefit-cost ratios under all sea level rise scenarios
- Economic viability increases under higher emission scenarios due to greater damage prevention
- Nature-based components provide long-term value through self-maintenance and adaptation

## Data Format and Usage

### MATLAB Files (.mat)
The case results files contain processed outputs from both XBNH wave modeling and subsequent analysis. These files include:
- Overtopping discharge time series
- Statistical measures of overtopping events  
- Processed data ready for SFINCS boundary conditions
- Temporal analysis of wave overtopping patterns

### NetCDF Files (.nc)
SFINCS output files contain spatially and temporally resolved flood simulation results including:
- Water depth grids at each time step
- Flow velocity fields
- Maximum flood extent and depth maps
- Duration of flooding at each grid cell
- Critical infrastructure impact assessments

## Model Configuration

### Spatial Resolution
- **XBNH Model**: High-resolution nearshore wave modeling with variable grid (10m offshore to 10cm near seawall)
- **SFINCS Model**: 1.5m grid spacing with ~570,000 active computational nodes
- **Study Domain**: Longport, New Jersey urban area (approximately 2.2 km²)

### Temporal Resolution
- **Hurricane Sandy Event**: October 27 - November 2, 2012
- **Model Time Step**: Dynamically adjusted for numerical stability
- **Data Processing**: Multi-stage smoothing applied to overtopping discharge time series

### Validation
- Model validation against USGS High Water Mark data from Hurricane Sandy
- Systematic calibration of infiltration rates and Manning roughness coefficients
- Accuracy assessment at measurement stations NJATL07248 and NJATL07247

## Requirements and Dependencies

### For MATLAB Analysis
```matlab
% Required MATLAB toolboxes:
% - Statistics and Machine Learning Toolbox
% - Signal Processing Toolbox
% - Mapping Toolbox (for spatial analysis)
```

### For NetCDF Data Analysis
```python
# Python libraries for SFINCS data analysis
import xarray as xr
import numpy as np
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
```

## Getting Started

### Loading Individual Case Results
```matlab
% Load specific case results
load('case_00_results.mat');

% Access overtopping time series
overtopping_discharge = results.overtopping.discharge;
time_series = results.overtopping.time;

% Plot overtopping comparison
figure;
plot(time_series, overtopping_discharge);
xlabel('Time');
ylabel('Overtopping Discharge (m³/s/m)');
title('Case 0: Control Scenario Overtopping');
```

### Analyzing SFINCS Flood Results
```python
# Load SFINCS NetCDF output
import xarray as xr
ds = xr.open_dataset('SFINCS_case_00.nc')

# Extract maximum flood depth
max_depth = ds.zsmax.values

# Create flood extent map
import matplotlib.pyplot as plt
plt.figure(figsize=(12, 8))
plt.imshow(max_depth, cmap='Blues', vmin=0, vmax=3)
plt.colorbar(label='Maximum Flood Depth (m)')
plt.title('Case 0: Maximum Flood Extent')
```

### Comparative Analysis
```matlab
% Load summary results for cross-scenario comparison
load('overtopping_summary.mat');

% Compare total overtopping volumes across all scenarios
scenarios = {'CS', 'CS+SLR1', 'CS+SLR2', 'DI+SLR1', 'DI+SLR2', 'DII+SLR1', 'DII+SLR2'};
volumes = summary.total_overtopping_volume;

figure;
bar(volumes);
set(gca, 'XTickLabel', scenarios);
ylabel('Total Overtopping Volume (m³/m)');
title('Overtopping Volume Comparison Across Scenarios');
```

## Citation

If you use this data or code in your research, please cite:

```
Amini, E., & Marsooli, R. (2025). Vegetation-Enhanced Seawalls Become More Functionally and
Economically Viable for Coastal Flood Risk Reduction as Sea Levels Rise: A Case Study  
[Journal information pending publication]
```

## Contact Information

For questions about the data, methodology, or code implementation, please contact:
- **Erfan Amini** (ea3246@columbia.edu)
  - Department of Civil, Environmental, and Ocean Engineering, Stevens Institute of Technology
  - Center for Climate Systems Research, Columbia University
  - 
## License

This dataset is made available for research and educational purposes. Please contact the authors for commercial use or redistribution.

## Acknowledgments

This research was conducted using:
- XBeach non-hydrostatic wave modeling software
- SFINCS coastal flood modeling framework developed by Deltares®
- USGS High Water Mark data from Hurricane Sandy
- NOAA C-CAP High-Resolution Land Cover data
- FEMA Flood Assessment Structure Tool (FAST)
- New Jersey Beach Profile Network (NJBPN) database
- Coastal National Elevation Database (CoNED)

---

**Repository Status**: Active  
**Last Updated**: 2025  
**Version**: 1.0.0
