% script_interim_addon.m
%
% This script processes datasets with addon files (e.g., addon_cnc, addon_video).
% It aligns timestamps and calibrates distances based on data extracted from the files.
% The script can handle cases where only CNC, only video, or both types of addons are present.
%
% DETAILS
%   Key features:
%   - Processes both CNC and video addons
%   - Aligns timestamps for both addon types with CSI data
%   - Handles timestamp synchronization with allowance for polling delay
%   - Calculates distances for video addons
%   - Handles flexible file naming conventions
%   
%   Timestamp Alignment:
%   Due to the file-based collection method, there is an inherent delay between
%   when data is collected and when the file creation is detected. This creates
%   a polling delay of up to 1 second that affects both CNC and video data
%   synchronization with CSI data.
%
% REVISIT
%   - Consider implementing UDP message for first sample timestamp
%   - Add time server synchronization over ethernet
%   - Make setting for local vs external machine timestamp usage
%   - Consider handling polling delay compensation in a unified way
%   - Add validation of timestamp alignment using movement signatures


%===============================================================================
% Global Constants
%===============================================================================

% File type patterns for addon files
ADDON_PATTERNS = struct(...
  'CNC', ["addon_gcode", "addon_cnc"], ...  % Use string array instead of cell array
  'VIDEO', "addon_video" ...
);

% Constants for timestamp alignment documentation
POLLING_DELAY_MAX = 1.0; % Maximum potential delay in seconds from file polling

%===============================================================================
% Settings
%===============================================================================

repoFolder = '../../openwifi_boards';
dataFolder = fullfile(repoFolder, 'data');

%===============================================================================
% Main execution
%===============================================================================

databaseFiles = find_database_files(dataFolder);
datasetsWithAddons = find_datasets_with_addons(databaseFiles, repoFolder, ADDON_PATTERNS);
process_datasets(datasetsWithAddons, repoFolder, ADDON_PATTERNS);

%===============================================================================
% Functions
%===============================================================================

%find_database_files: Scans the data folder for JSON files containing dataset information
%
% USAGE
%   databaseFiles = find_database_files(dataFolder)
%
% INPUT PARAMETERS
%   dataFolder: Path to the data folder (e.g., '/path/to/openwifi_boards/data')
%
% OUTPUT PARAMETERS
%   databaseFiles: Cell array of strings containing paths to database.json files
%
% DETAILS
%   Recursively searches through the provided data folder and its subfolders
%   for database.json files that contain experiment metadata.
%
function databaseFiles = find_database_files(dataFolder)
  databaseFiles = {};
  folders = genpath(dataFolder);
  folderList = strsplit(folders, pathsep);

  for i = 1:length(folderList)
    jsonFile = fullfile(folderList{i}, 'database.json');
    if exist(jsonFile, 'file')
      databaseFiles{end+1} = jsonFile; % Corrected line
    end
  end
  
  if isempty(databaseFiles)
    warning('No database.json files found in the specified data folder.');
  end
end

%find_addon_files: Locates CNC and video addon files for a dataset
%
% USAGE
%   addonFiles = find_addon_files(expFnameBase, repoFolder, ADDON_PATTERNS)
%
% INPUT PARAMETERS
%   expFnameBase: Base filename for the experiment
%   repoFolder  : Path to the repository folder
%   ADDON_PATTERNS: Struct containing addon file patterns
%
% OUTPUT PARAMETERS
%   addonFiles: Cell array of addon filenames found
%
% DETAILS
%   Searches for both CNC and video addon files in the raw data directory
%   CNC files pattern: *addon_gcode*.csv or *addon_cnc*.csv
%   Video files pattern: *addon_video*.csv
%
function addonFiles = find_addon_files(expFnameBase, repoFolder, ADDON_PATTERNS)
  % Find CNC addon files using both allowed patterns
  cncFiles = {};
  for pattern = ADDON_PATTERNS.CNC   
    cncPattern = strcat(expFnameBase, "*", pattern, "*.csv");
    cncPattern = strrep(cncPattern, 'data/interim', 'data/raw');
    files = dir(fullfile(repoFolder, cncPattern));
    if ~isempty(files)
      cncFiles = [cncFiles; {files.name}];
    end
  end

  % Find video addon files
  videoPattern = strcat(expFnameBase, "*", ADDON_PATTERNS.VIDEO, "*.csv");
  videoPattern = strrep(videoPattern, 'data/interim', 'data/raw');
  videoFiles   = dir(fullfile(repoFolder, videoPattern));

  % Combine all addon files
  addonFiles = [cncFiles, {videoFiles.name}];
end

%process_datasets: Main function to process all datasets and their addon files
%
% USAGE
%   process_datasets(datasetsWithAddons, repoFolder, ADDON_PATTERNS)
%
% INPUT PARAMETERS
%   datasetsWithAddons: Cell array of structs containing dataset information
%   repoFolder       : Path to the repository folder
%   ADDON_PATTERNS   : Struct containing addon file patterns
%
% DETAILS
%   For each dataset:
%   1. Loads the interim data
%   2. Processes each addon file (CNC or video)
%   3. Updates the interim data with processed addon information
%   4. Saves the updated data back to the MAT file
%
%   Note on Timestamp Alignment:
%   Both CNC and video addons need to handle potential polling delays in their
%   timestamp alignment. The local_machine_first_sample_unix timestamp used for
%   alignment may be 0-1 second later than the actual first sample time due to
%   the polling-based file detection system.
%
function process_datasets(datasetsWithAddons, repoFolder, ADDON_PATTERNS)
  for i = 1:length(datasetsWithAddons)
    dataset = datasetsWithAddons{i};
    
    [expDir, ~, ~] = fileparts(dataset.expFnameBase);
    interimFilePath = fullfile(repoFolder, expDir, dataset.interimFile);
    interimData     = load(interimFilePath);

    if ~isfield(interimData, 'addon')
      interimData.addon = struct();
    end

    for j = 1:length(dataset.addonFiles)
      addonFile = dataset.addonFiles{j};
      rawFolderName = strrep(fullfile(repoFolder, expDir), 'interim', 'raw');
      addonFilePath = fullfile(rawFolderName, addonFile);

      % Determine addon type and process accordingly
      if any(cellfun(@(x) contains(addonFile, x), ADDON_PATTERNS.CNC))
        addonData = cnc_addon_process(addonFilePath, dataset.jsonData);
        addonType = 'cnc';
      elseif contains(addonFile, ADDON_PATTERNS.VIDEO)
        addonData = video_addon_process(addonFilePath, addonFile, dataset.jsonData);
        addonType = 'walking_tracking';
      else
        warning('Unknown addon type for file: %s', addonFile);
        continue;
      end

      interimData.addon.(addonType) = addonData;
    end

    save(interimFilePath, '-struct', 'interimData');
    fprintf('Updated interim file: %s\n', interimFilePath);
  end
  
  if isempty(datasetsWithAddons)
      warning('No datasets with addons found.');
  end
end


%cnc_addon_process: Processes CNC position data from addon files
%
% USAGE
%   addonData = cnc_addon_process(addonFilePath, jsonData)
%
% INPUT PARAMETERS
%   addonFilePath: Path to the CNC addon CSV file
%   jsonData     : Struct containing dataset information from database.json
%
% OUTPUT PARAMETERS
%   addonData: Table containing processed CNC data with fields:
%              - timestamp_aligned_second: Timestamps aligned with CSI data
%              - position_x_mm: X position in meters
%              - position_y_mm: Y position in meters
%              - distance_m: Distance from origin in meters
%
% DETAILS
%   CSV Format:
%   - timestamp_unix: Unix timestamp in seconds from CNC machine
%   - timestamp_second: Relative timestamp in seconds
%   - position_x_mm: X position in millimeters
%   - position_y_mm: Y position in millimeters
%   - command: Command sent to CNC machine
%
%   Timestamp Alignment:
%   When aligning timestamps to local_machine_first_sample_unix, you have aligned 
%   it to a timepoint that is potentially 0 to 1 second too late, so for the CNC 
%   timestamps, you have to subtract 0 to 1 second to achieve proper alignment.
%   This delay occurs because:
%   1. The system polls for new files approximately every 0.5-1 second
%   2. A file might be created right after a poll, leading to detection delay
%   3. The local_machine_first_sample_unix represents when we first saw the file
%
%   Time Synchronization:
%   The CNC machine's clock should ideally be synchronized with the machine
%   reading the OpenWiFi board data. For best results:
%   1. Use the same machine for CNC control and data collection if possible
%   2. If using separate machines, ensure proper NTP synchronization
%   3. Consider the polling delay when analyzing timing-critical events
%
function addonData = cnc_addon_process(addonFilePath, jsonData)
  addonData = readtable(addonFilePath, 'Delimiter', ',');
  
  % Align timestamps with local machine first sample
  % Note: This alignment may be 0-1 second too late due to polling delay
  addonData.timestamp_aligned_second = addonData.timestamp_unix - jsonData.local_machine_first_sample_unix;
  
  % Convert positions to meters and calculate distance from origin
  if ismember('position_x_mm', addonData.Properties.VariableNames)
    addonData.position_x_mm = addonData.position_x_mm / 1000;
    addonData.position_y_mm = addonData.position_y_mm / 1000;
    addonData.distance_m    = sqrt(addonData.position_x_mm.^2 + addonData.position_y_mm.^2);
  end
  
  disp('  CNC addon processed: Aligned timestamps and distances.');
end


%video_addon_process: Processes video tracking data from addon files
%
% USAGE
%   addonData = video_addon_process(addonFilePath, addonFile, jsonData)
%
% INPUT PARAMETERS
%   addonFilePath: Path to the video addon CSV file
%   addonFile   : Name of the video file (for timestamp extraction)
%   jsonData    : Struct containing dataset information
%
% OUTPUT PARAMETERS
%   addonData: Table containing processed video data with fields:
%              - timestamp_unix: Unix timestamp
%              - timestamp_aligned_second: Timestamps aligned with CSI data
%              - distance_meter: Distance between walking person and OpenWiFi board
%
% DETAILS
%   CSV Format:
%   - position_openwifi_meter: OpenWiFi board position in meters
%   - position_walking_meter: Walking person position in meters
%   - timestamp_video_minute: Video timestamp minutes
%   - timestamp_video_second: Video timestamp seconds
%
%   Timestamp Alignment:
%   Video timing involves multiple timestamps that need careful handling:
%   1. Video file timestamp (from filename): Indicates when recording started
%   2. In-video timestamps: Relative time since recording start
%   3. Polling delay: Similar to CNC data, there's a 0-1 second potential delay
%      between file creation and detection
%
%   Time Synchronization Considerations:
%   - Video timestamps come from the phone's internal clock
%   - The phone should ideally be synchronized with a reliable time server
%   - For walking experiments, consider using movement signatures in the
%     CSI data to validate timestamp alignment
%   - Similar to CNC data, the local_machine_first_sample_unix timestamp
%     may be 0-1 second later than actual due to polling delay
%
function addonData = video_addon_process(addonFilePath, addonFile, jsonData)
  addonData = readtable(addonFilePath, 'Delimiter', ',');
  
  % Extract timestamp from video filename and convert to Unix timestamp
  videoTimestampUTC = video_addon_extract_timestamp(addonFile);
  
  % Generate absolute timestamps by combining video start time with relative timestamps
  addonData.timestamp_unix = posixtime(videoTimestampUTC) + addonData.timestamp_video_minute * 60 + addonData.timestamp_video_second;
  
  % Align timestamps with dataset start time
  % Note: Similar to CNC data, this alignment may need 0-1 second adjustment
  % due to polling delay in file detection
  addonData.timestamp_aligned_second = addonData.timestamp_unix - jsonData.local_machine_first_sample_unix;
  
  % Calculate distance between walking person and OpenWiFi board
  addonData.distance_meter = addonData.position_walking_meter - addonData.position_openwifi_meter(1);
  
  disp('  Video addon processed: Generated timestamps and distances.');
end


%video_addon_extract_timestamp: Extracts timestamp from PXL format video filenames
%
% USAGE
%   videoTimestampUTC = video_addon_extract_timestamp(videoFilename)
%
% INPUT PARAMETERS
%   videoFilename: Name of the video file
%
% OUTPUT PARAMETERS
%   videoTimestampUTC: UTC datetime object of video timestamp
%
% DETAILS
%   Filename Format: PXL_YYYYMMDD_HHMMSS[SSS].TS.mp4
%   Examples:
%   - PXL_20241014_054134901.TS.mp4 (with milliseconds)
%   - PXL_20241014_054134.TS.mp4 (without milliseconds)
%
function videoTimestampUTC = video_addon_extract_timestamp(videoFilename)
  filenamePattern = 'PXL_(\d{8})_(\d{6})(\d{3})?';
  tokens = regexp(videoFilename, filenamePattern, 'tokens');

  if isempty(tokens)
    error('Filename does not match the expected pattern: %s', videoFilename);
  end

  dateStr = tokens{1}{1}; % YYYYMMDD
  timeStr = tokens{1}{2}; % HHMMSS
  msStr   = tokens{1}{3}; % SSS (optional)

  if isempty(msStr)
    videoTimestampUTC = datetime([dateStr, timeStr], 'InputFormat', 'yyyyMMddHHmmss', 'TimeZone', 'UTC');
  else
    videoTimestampUTC = datetime([dateStr, timeStr, msStr], 'InputFormat', 'yyyyMMddHHmmssSSS', 'TimeZone', 'UTC');
  end
end

%find_datasets_with_addons: Identifies datasets that have corresponding addon files
%
% USAGE
%   datasetsWithAddons = find_datasets_with_addons(databaseFiles, repoFolder, ADDON_PATTERNS)
%
% INPUT PARAMETERS
%   databaseFiles: Cell array of strings with paths to database.json files
%   repoFolder  : Path to the repository folder
%   ADDON_PATTERNS: Struct containing addon file patterns
%
% OUTPUT PARAMETERS
%   datasetsWithAddons: Cell array of structs containing dataset information
%                      Each struct contains:
%                      - databaseFile: path to source database.json
%                      - fileId: unique identifier for the dataset
%                      - expFnameBase: base filename for the experiment
%                      - interimFile: corresponding interim .mat file
%                      - addonFiles: cell array of addon filenames
%                      - jsonData: raw JSON data for the dataset
%
function datasetsWithAddons = find_datasets_with_addons(databaseFiles, repoFolder, ADDON_PATTERNS)
  datasetsWithAddons = {};

  for i = 1:length(databaseFiles)
    jsonStr     = fileread(databaseFiles{i});
    jsonData    = jsondecode(jsonStr);
    datasetKeys = fieldnames(jsonData);

    for j = 1:length(datasetKeys)
      fileId = datasetKeys{j};
      expJsonDataFile = jsonData.(fileId);
      expFnameBase    = expJsonDataFile.fname_base;

      interimFile = find_interim_file(expFnameBase, repoFolder);
      if ~isempty(interimFile)
        addonFiles = find_addon_files(expFnameBase, repoFolder, ADDON_PATTERNS);
        if ~isempty(addonFiles)
          datasetsWithAddons{end+1} = struct(...
            'databaseFile', databaseFiles{i}, ...
            'fileId', fileId, ...
            'expFnameBase', expFnameBase, ...
            'interimFile', interimFile, ...
            'addonFiles', {addonFiles}, ...
            'jsonData', expJsonDataFile ...
          );
        end
      end
    end
  end
  
  if isempty(datasetsWithAddons)
    warning('No datasets with addons found.');
  end
end


%find_interim_file: Locates the interim MAT file for a given dataset
%
% USAGE
%   interimFile = find_interim_file(expFnameBase, repoFolder)
%
% INPUT PARAMETERS
%   expFnameBase: Base filename for the experiment
%   repoFolder  : Path to the repository folder
%
% OUTPUT PARAMETERS
%   interimFile: Name of the interim MAT file or empty string if not found
%
% DETAILS
%   Searches for MAT files matching the pattern [expFnameBase]*interim*.mat
%   Returns the first matching file found
%
function interimFile = find_interim_file(expFnameBase, repoFolder)
  interimPattern     = [expFnameBase, '*interim*.mat'];
  interimFilePattern = fullfile(repoFolder, interimPattern);
  interimFileStruct  = dir(interimFilePattern);

  if ~isempty(interimFileStruct)
    interimFile = interimFileStruct(1).name;
  else
    interimFile = '';
  end
end
