%% Extract Overtopping Data to Text Files
% Clear workspace
clear all
close all
clc

%% USER INPUTS - All configurable parameters listed here
% Input/output paths
input_mat_file = './overtopping_results/overtopping_summary.mat';
output_folder = './extracted_data';

% Processing parameters
smoothing_window_minutes = 20.0;    % Size of smoothing window in minutes
process_scenarios = 2;              % Which scenarios to process
scenario_to_plot = 2;               % Which scenario to plot at the end

% Plot settings
y_axis_max = 1.0;                   % Maximum value for right y-axis in plots 

% Reference time for the simulation
ref_date = datetime(2012, 10, 27, 8, 40, 0);  % October 27, 2012, 08:40 am

%% SETUP - Create output folder
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
    fprintf('Created output folder: %s\n', output_folder);
end

%% LOAD DATA - Read the MAT file
fprintf('Loading MAT file: %s\n', input_mat_file);
mat_data = load(input_mat_file);

% Create a summary file
summary_file = fullfile(output_folder, 'scenarios_summary.txt');
fid = fopen(summary_file, 'w');
fprintf(fid, 'ScenarioIndex,NumDataPoints,HasTimeVector,OriginalPoints,ProcessedPoints\n');

%% PROCESS SCENARIOS - Process each selected scenario
fprintf('\nStarting processing of %d scenarios...\n', length(process_scenarios));

for scenario_idx_loop = 1:length(process_scenarios)
    scenario_idx = process_scenarios(scenario_idx_loop);
    fprintf('\nProcessing scenario %d (task %d of %d)...\n', scenario_idx, scenario_idx_loop, length(process_scenarios));
    
    % Convert from 0-based to 1-based for MATLAB indexing
    matlab_idx = scenario_idx + 1;
    
    % Access time series data
    time_series = [];
    time_vector = [];
    
    if iscell(mat_data.sorted_timeseries) && matlab_idx <= length(mat_data.sorted_timeseries)
        time_series = mat_data.sorted_timeseries{matlab_idx};
    elseif size(mat_data.sorted_timeseries, 2) >= matlab_idx
        time_series = mat_data.sorted_timeseries(:, matlab_idx);
    elseif size(mat_data.sorted_timeseries, 1) >= matlab_idx
        time_series = mat_data.sorted_timeseries(matlab_idx, :)';
    else
        fprintf('Scenario %d: Cannot access time series\n', scenario_idx);
        continue;
    end
    
    % Access time vector data
    if iscell(mat_data.sorted_time_vectors) && matlab_idx <= length(mat_data.sorted_time_vectors)
        time_vector = mat_data.sorted_time_vectors{matlab_idx};
    elseif size(mat_data.sorted_time_vectors, 2) >= matlab_idx
        time_vector = mat_data.sorted_time_vectors(:, matlab_idx);
    elseif size(mat_data.sorted_time_vectors, 1) >= matlab_idx
        time_vector = mat_data.sorted_time_vectors(matlab_idx, :)';
    else
        time_vector = [];
    end
    
    % Make sure data is in the right shape (column vector)
    if ~isempty(time_series)
        if size(time_series, 1) == 1
            time_series = time_series';
        end
        
        % Save original unsmoothed data for comparison
        orig_time_series = time_series;
        
        % Check range of original data
        fprintf('Original data range: min=%.2f, max=%.2f\n', min(time_series), max(time_series));
        
        % Replace NaN values with 0
        nan_count = sum(isnan(time_series));
        if nan_count > 0
            fprintf('Replacing %d NaN values with 0\n', nan_count);
            time_series(isnan(time_series)) = 0;
        end
        
        % Apply smoothing to reduce oscillations
        fprintf('Applying smoothing with %d minute window...\n', smoothing_window_minutes);
        
        % Calculate window size in points (assuming 1s time step)
        sec_per_minute = 60;
        minute_window = round(smoothing_window_minutes * sec_per_minute);
        
        % Make sure window is reasonable
        if minute_window < 5
            minute_window = 5;
        end
        
        % Apply smoothing with user-specified window
        if length(time_series) > minute_window
            % Ensure window length is odd for centered moving average
            if mod(minute_window, 2) == 0
                minute_window = minute_window + 1;
            end
            
            % Create a copy of the data for smoothing
            smooth_series = time_series;
            
            % Count zeros before smoothing
            zero_count_before = sum(smooth_series == 0);
            fprintf('Zero values before smoothing: %d\n', zero_count_before);
            
            % Apply Gaussian smoothing filter (first pass)
            fprintf('Using Gaussian smoothing with %d-point window\n', minute_window);
            
            % IMPORTANT: For proper smoothing that preserves zeros, explicitly set options
            smooth_series = smoothdata(smooth_series, 'gaussian', minute_window, 'includenan');
            
            % Apply second smoothing pass with Savitzky-Golay filter
            if length(smooth_series) > minute_window
                % Must be odd and less than window size
                poly_order = 3;
                sg_window = min(minute_window, 501);
                if mod(sg_window, 2) == 0
                    sg_window = sg_window - 1;
                end
                
                % Apply filter if we have enough points
                if sg_window > poly_order
                    try
                        fprintf('Applying Savitzky-Golay filter with order %d and window %d\n', poly_order, sg_window);
                        smooth_series = sgolayfilt(smooth_series, poly_order, sg_window);
                    catch ME
                        % Continue with Gaussian smoothed data
                        fprintf('Savitzky-Golay filter failed: %s\nKeeping Gaussian smoothed data.\n', ME.message);
                    end
                end
            end
            
            % Count zeros after smoothing
            zero_count_after = sum(smooth_series == 0);
            fprintf('Zero values after smoothing: %d\n', zero_count_after);
            
            % Replace original series with smoothed series
            time_series = smooth_series;
        else
            fprintf('Time series too short for specified window, applying minimal smoothing\n');
            % For very short series, just use simple moving average
            try
                time_series = smoothdata(time_series, 'movmean', 5, 'includenan');
            catch
                % Keep original if even simple smoothing fails
                fprintf('Basic smoothing failed, keeping original data\n');
            end
        end
        
        % Replace any negative values with zeros after smoothing
        neg_count = sum(time_series < 0);
        if neg_count > 0
            fprintf('Replacing %d negative values with 0 after smoothing\n', neg_count);
            time_series(time_series < 0) = 0;
        end
        
        % Check range of smoothed data
        fprintf('Smoothed data range: min=%.2f, max=%.2f\n', min(time_series), max(time_series));
        
        % Compare before and after smoothing
        if ~isempty(orig_time_series)
            max_orig = max(orig_time_series);
            max_smooth = max(time_series);
            fprintf('Max value before smoothing: %.2f, after: %.2f\n', max_orig, max_smooth);
        end
    else
        fprintf('Scenario %d: Time series is empty\n', scenario_idx);
        continue;
    end
    
    if ~isempty(time_vector) && size(time_vector, 1) == 1
        time_vector = time_vector';
    end
    
    %% SAVE SFINCS FORMAT DATA WITH SMOOTHED DATA
    output_file = fullfile(output_folder, sprintf('scenario_%d_for_sfincs.txt', scenario_idx));
    
    if ~isempty(time_series) && ~isempty(time_vector)
        % Create SFINCS header
        fid_out = fopen(output_file, 'w');
        fprintf(fid_out, 'Time_seconds,Scenario_%d\n', scenario_idx);
        
        % The first row is always zero
        fprintf(fid_out, '0.00,0.00\n');
        
        % Get original time steps
        orig_time_steps = length(time_vector);
        
        % Update summary info 
        fprintf(fid, '%d,%d,%d,%d,%d\n', scenario_idx, length(time_series), ...
               ~isempty(time_vector), orig_time_steps, orig_time_steps);
        
        % Store for plotting (if this is the scenario to plot)
        sfincs_times = zeros(orig_time_steps+1, 1);
        sfincs_values = zeros(orig_time_steps+1, 1);
        sfincs_times(1) = 0;
        sfincs_values(1) = 0;
        
        % Write each time point with smoothed data
        fprintf('Writing smoothed data to SFINCS format file...\n');
        
        % Sample a few values to verify
        sample_indices = round(linspace(1, orig_time_steps, min(5, orig_time_steps)));
        fprintf('Sample values from smoothed data:\n');
        for i = 1:length(sample_indices)
            idx = sample_indices(i);
            fprintf('  Index %d: time=%.1f, value=%.2f\n', idx, time_vector(idx), time_series(idx));
        end
        
        % Process in chunks for more progress updates
        chunk_size = 10000;
        num_chunks = ceil(orig_time_steps / chunk_size);
        
        for chunk = 1:num_chunks
            start_idx = (chunk-1)*chunk_size + 1;
            end_idx = min(chunk*chunk_size, orig_time_steps);
            
            for i = start_idx:end_idx
                time_sec = time_vector(i);
                discharge = time_series(i);  % This is the smoothed data
                
                % Write to file with 2 decimal places
                fprintf(fid_out, '%.2f,%.2f\n', time_sec, discharge);
                
                % Store for plotting
                sfincs_times(i+1) = time_sec;
                sfincs_values(i+1) = discharge;
            end
            
            if mod(chunk, 5) == 0 || chunk == num_chunks
                fprintf('Scenario %d: Wrote chunk %d of %d to SFINCS file\n', scenario_idx, chunk, num_chunks);
            end
        end
        
        fclose(fid_out);
        fprintf('SFINCS format file created with smoothed data.\n');
        
        % Save plotting data if this is the scenario we want to plot
        if scenario_idx == scenario_to_plot
            plot_data_file = fullfile(output_folder, sprintf('scenario_%d_plot_data.mat', scenario_idx));
            
            % Save data for plotting
            plot_data.times = sfincs_times;
            plot_data.values = sfincs_values;
            plot_data.orig_series = orig_time_series;
            plot_data.orig_vector = time_vector;
            save(plot_data_file, 'plot_data');
            fprintf('Saved plot data for scenario %d\n', scenario_idx);
        end
    end
    
    fprintf('Scenario %d: Processing completed successfully\n', scenario_idx);
end

fclose(fid);
fprintf('\nExtraction complete. Files saved to: %s\n', output_folder);

%% PLOTTING SECTION - Create a plot of the specified scenario
fprintf('\nPlotting discharge time series for scenario %d...\n', scenario_to_plot);

% Path to the SFINCS-ready file for the selected scenario
plot_file = fullfile(output_folder, sprintf('scenario_%d_for_sfincs.txt', scenario_to_plot));
plot_data_file = fullfile(output_folder, sprintf('scenario_%d_plot_data.mat', scenario_to_plot));

if exist(plot_file, 'file') && exist(plot_data_file, 'file')
    % Read the plotting data
    load(plot_data_file);
    
    % Read the SFINCS file to verify it contains the expected data
    plot_table = readtable(plot_file);
    
    % Extract column names and data
    col_names = plot_table.Properties.VariableNames;
    time_secs = plot_table.(col_names{1});
    discharge = plot_table.(col_names{2});
    
    % Check range of values in the file
    fprintf('Range of values in SFINCS file: min=%.2f, max=%.2f\n', min(discharge), max(discharge));
    
    % Create date array
    time_dates = cell(size(time_secs));
    for i = 1:length(time_secs)
        % Add seconds to the reference date
        curr_date = addtodate(datenum(ref_date), round(time_secs(i)), 'second');
        % Format as string
        time_dates{i} = datestr(curr_date, 'dd-mmm HH:MM');
    end
    
    % For the actual plotting, create numerical x values for proper spacing
    % Use hours from start for even spacing
    time_hours = time_secs / 3600;
    
    % Create the figure
    figure('Name', sprintf('Scenario %d Discharge', scenario_to_plot), 'Position', [100, 100, 1200, 800]);
    
    % Check if we have the original data for comparison
    has_original_data = isfield(plot_data, 'orig_series') && isfield(plot_data, 'orig_vector');
    
    % Primary plot: Full time series
    subplot(2,1,1);
    
    % First plot original data in light gray if available
    if has_original_data
        % Original raw data for comparison
        orig_time_series = plot_data.orig_series;
        orig_time_vector = plot_data.orig_vector;
        orig_time_hours = orig_time_vector / 3600;
        
        % Plot with separate y-axis to handle different scales
        yyaxis left
        plot(orig_time_hours, orig_time_series, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
        ylabel('Raw q_x (m³/s/m)', 'Color', [0.4 0.4 0.4], 'FontWeight', 'bold');
        ax1 = gca;
        ax1.YColor = [0.4 0.4 0.4];
        
        % Calculate suitable y-axis limits for raw data
        raw_max = max(orig_time_series) * 1.1; % Add 10% margin
        if raw_max > 0
            ylim([0 raw_max]);
        end
        
        hold on;
    end
    
    % Then plot processed data with thicker blue line on right y-axis
    yyaxis right
    plot(time_hours, discharge, 'b-', 'LineWidth', 2.5);
    grid on;
    ylabel('Processed q_x (m³/s/m)', 'Color', 'blue', 'FontWeight', 'bold');
    ax2 = gca;
    ax2.YColor = 'blue';
    
    % Set y-axis limits for processed data to user-specified range
    ylim([0 y_axis_max]);
    
    % Set x-ticks at regular intervals and label with actual dates
    num_ticks = 8; % Number of date ticks to show
    tick_indices = round(linspace(1, length(time_hours), num_ticks));
    tick_hours = time_hours(tick_indices);
    tick_labels = time_dates(tick_indices);
    
    % Set custom x-ticks
    set(gca, 'XTick', tick_hours);
    set(gca, 'XTickLabel', tick_labels);
    
    title('(a) Time Series Comparison', 'FontSize', 14);
    xlabel('Date and Time (starting Oct 27, 2012, 08:40 am)', 'FontSize', 12);
    
    % Add legend
    if has_original_data
        legend('Raw Data (XBeach output)', 'Processed (Smoothed)', 'Location', 'northeast');
    end
    
    % Calculate some stats
    max_discharge = max(discharge);
    total_discharge = sum(discharge);  % Simple sum since time step = 1s
    
    % Add text with statistics (on the processed data side)
    yyaxis right
    text(0.02, 0.95, sprintf('Max q_x: %.2f m³/s/m', max_discharge), ...
        'Units', 'normalized', 'FontSize', 12, 'Color', 'blue', 'FontWeight', 'bold');
    text(0.02, 0.87, sprintf('Total Volume: %.2f m³/m', total_discharge), ...
        'Units', 'normalized', 'FontSize', 12, 'Color', 'blue');
    text(0.02, 0.79, sprintf('Data Points: %d', length(time_secs)), ...
        'Units', 'normalized', 'FontSize', 12, 'Color', 'blue');
    text(0.02, 0.71, sprintf('Smoothing Window: %.1f minutes', smoothing_window_minutes), ...
        'Units', 'normalized', 'FontSize', 12, 'Color', 'blue');
    text(0.02, 0.63, sprintf('Start Time: %s', datestr(ref_date, 'dd-mmm-yyyy HH:MM')), ...
        'Units', 'normalized', 'FontSize', 12, 'Color', 'blue');
    
    % Second plot: Zoomed view of peak discharge
    subplot(2,1,2);
    
    % Find region around peak
    [peak_val, peak_idx] = max(discharge);
    window = min(500, round(length(discharge)/4));  % Number of points before and after peak to show
    
    % Calculate window bounds
    start_idx = max(1, peak_idx - window);
    end_idx = min(length(discharge), peak_idx + window);
    
    % Extract data for zoomed view
    zoom_hours = time_hours(start_idx:end_idx);
    zoom_discharge = discharge(start_idx:end_idx);
    zoom_dates = time_dates(start_idx:end_idx);
    
    % Define the time range for zooming (in hours)
    zoom_start_hour = zoom_hours(1);
    zoom_end_hour = zoom_hours(end);
    
    % First plot original raw data in zoomed view if available
    if has_original_data
        % Find original data points within the zoom time range
        orig_zoom_indices = find(orig_time_hours >= zoom_start_hour & orig_time_hours <= zoom_end_hour);
        
        if ~isempty(orig_zoom_indices)
            % Plot with separate y-axis to handle different scales
            yyaxis left
            plot(orig_time_hours(orig_zoom_indices), orig_time_series(orig_zoom_indices), ...
                 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
            ylabel('Raw q_x (m³/s/m)', 'Color', [0.4 0.4 0.4], 'FontWeight', 'bold');
            ax1 = gca;
            ax1.YColor = [0.4 0.4 0.4];
            
            % Calculate suitable y-axis limits for raw data in zoom view
            raw_zoom_data = orig_time_series(orig_zoom_indices);
            raw_zoom_max = max(raw_zoom_data) * 1.1; % Add 10% margin
            if raw_zoom_max > 0
                ylim([0 raw_zoom_max]);
            end
            
            hold on;
        end
    end
    
    % Plot zoomed section of processed data on right y-axis
    yyaxis right
    plot(zoom_hours, zoom_discharge, 'b-', 'LineWidth', 2.5);
    grid on;
    ylabel('Processed q_x (m³/s/m)', 'Color', 'blue', 'FontWeight', 'bold');
    ax2 = gca;
    ax2.YColor = 'blue';
    
    % Set y-axis limits for processed data to user-specified range
    ylim([0 y_axis_max]);
    
    % Add legend with only 2 entries
    if has_original_data && ~isempty(orig_zoom_indices)
        legend('Raw Data', 'Processed', 'Location', 'northeast');
    end
    
    % Set custom x-ticks for zoomed plot
    num_zoom_ticks = 5; % Number of date ticks to show in zoomed plot
    zoom_tick_indices = round(linspace(1, length(zoom_hours), num_zoom_ticks));
    zoom_tick_hours = zoom_hours(zoom_tick_indices);
    zoom_tick_labels = zoom_dates(zoom_tick_indices);
    
    % Set zoomed plot x-ticks
    set(gca, 'XTick', zoom_tick_hours);
    set(gca, 'XTickLabel', zoom_tick_labels);
    
    title('(b) Peak Discharge Region', 'FontSize', 14);
    xlabel('Date and Time', 'FontSize', 12);
    
    % Add peak point marker (not in legend)
    yyaxis right
    hold on;
    plot(time_hours(peak_idx), peak_val, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
    peak_date_str = time_dates{peak_idx};
    text(time_hours(peak_idx), peak_val*1.1, sprintf('Peak: %.2f m³/s/m at %s', peak_val, peak_date_str), ...
        'FontSize', 12, 'HorizontalAlignment', 'center', 'Color', 'blue');
    hold off;
    
    % Save the figure - only PNG, not FIG
    saveas(gcf, fullfile(output_folder, sprintf('scenario_%d_plot.png', scenario_to_plot)), 'png');
    
    fprintf('Plot created and saved to: %s\n', fullfile(output_folder, sprintf('scenario_%d_plot.png', scenario_to_plot)));
else
    fprintf('ERROR: Could not find files to plot for scenario %d\n', scenario_to_plot);
end
