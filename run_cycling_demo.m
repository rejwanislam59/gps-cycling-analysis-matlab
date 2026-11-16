%% GPS-Based Cycling Performance Analysis — Personal Portfolio Demonstration
% Independent post-course educational reimplementation; NOT the original
% assessed group submission. Uses a wholly SYNTHETIC GPX track by default.
% Tested conceptually/reference-checked with Python; run in MATLAB to verify.
% Requirements: MATLAB R2020a+ (exportgraphics), no special toolbox intended.

clear; clc; close all;
projectFolder = fileparts(mfilename('fullpath'));
inputFile = fullfile(projectFolder, 'data', 'synthetic_ride.gpx');
outputFolder = fullfile(projectFolder, 'results');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% 1 — Import a GPX using low-level file input
[latitude, longitude, elevationM, utcTimes] = readGPXTrack(inputFile);
if numel(latitude) < 2
    error('At least two complete GPX track points are required.');
end

elapsedSec = seconds(utcTimes - utcTimes(1));
if any(diff(elapsedSec) <= 0)
    error('GPX timestamps must be strictly increasing for this demo.');
end
localTimes = utcTimes;
localTimes.TimeZone = 'Australia/Sydney';
trackTable = table(localTimes, latitude, longitude, elevationM, ...
    'VariableNames', {'LocalTime', 'Latitude', 'Longitude', 'ElevationM'});
fprintf('Imported %d track points.\n', height(trackTable));

%% 2 — WGS84 geographic coordinates to local UTM projection
[eastM, northM, zone] = gpsToUTM(latitude, longitude);
relativeEastM = eastM - eastM(1);
relativeNorthM = northM - northM(1);
fprintf('Single UTM zone used: %d.\n', zone);

%% 3 — Distance, speed and gradient from adjacent track points
n = numel(elapsedSec);
stepEastM  = [0; diff(relativeEastM)];
stepNorthM = [0; diff(relativeNorthM)];
stepUpM    = [0; diff(elevationM)];
stepTimeS  = [0; diff(elapsedSec)];
horizontalStepM = hypot(stepEastM, stepNorthM);
threeDStepM = hypot(horizontalStepM, stepUpM);
distanceKm = cumsum(threeDStepM) / 1000;
speedMps = zeros(n, 1);
speedMps(2:end) = threeDStepM(2:end) ./ stepTimeS(2:end);
speedKmh = 3.6 * speedMps;

% Ignore grade when horizontal motion is too small for a stable ratio.
gradePercent = zeros(n, 1);
validStep = horizontalStepM >= 0.5;
gradePercent(validStep) = 100 * stepUpM(validStep) ./ horizontalStepM(validStep);

%% 4 — Simple model of rider power and cumulative energy
riderMassKg = 80;
bicycleMassKg = 14;
totalMassKg = riderMassKg + bicycleMassKg;
g = 9.80665;
rollingCoefficient = 0.0253;
airDensity = 1.225;
dragArea = 0.408;
drivetrainLossFraction = 0.03;
slopeAngle = atan(gradePercent / 100);

forceSlopeN = totalMassKg * g * sin(slopeAngle);
forceRollingN = totalMassKg * g * rollingCoefficient * cos(slopeAngle);
forceAirN = 0.5 * airDensity * dragArea .* speedMps.^2;

% Idealised cyclist-propulsion estimate only; not measured pedal power.
powerW = max(0, (forceSlopeN + forceRollingN + forceAirN) .* ...
    speedMps / (1 - drivetrainLossFraction));
energyJ = zeros(n, 1);
for k = 2:n
    energyJ(k) = energyJ(k-1) + ...
        0.5 * (powerW(k-1) + powerW(k)) * stepTimeS(k);
end

%% 5 — Export six MATLAB figures
f1 = figure('Name', '3D route');
plot3(relativeEastM/1000, relativeNorthM/1000, elevationM, 'LineWidth', 1.4);
grid on; xlabel('Relative Easting (km)'); ylabel('Relative Northing (km)');
zlabel('Elevation (m)'); title('Synthetic ride: 3D GPS path');
exportgraphics(f1, fullfile(outputFolder,'matlab_01_3d_route.png'));

f2 = figure('Name','Elevation and grade');
yyaxis left; plot(elapsedSec, elevationM); ylabel('Elevation (m)');
yyaxis right; plot(elapsedSec, gradePercent); ylabel('Grade (%)');
grid on; xlabel('Elapsed time (s)'); title('Synthetic ride: elevation and grade');
exportgraphics(f2, fullfile(outputFolder,'matlab_02_elevation_grade.png'));

f3 = figure('Name','Distance');
plot(elapsedSec, distanceKm); grid on;
xlabel('Elapsed time (s)'); ylabel('Cumulative 3D distance (km)');
title('Synthetic ride: cumulative distance');
exportgraphics(f3, fullfile(outputFolder,'matlab_03_distance.png'));

f4 = figure('Name','Speed over time');
plot(elapsedSec, speedKmh); grid on;
xlabel('Elapsed time (s)'); ylabel('Speed (km/h)');
title('Synthetic ride: speed versus time');
exportgraphics(f4, fullfile(outputFolder,'matlab_04_speed_time.png'));

f5 = figure('Name','Speed over distance');
plot(distanceKm, speedKmh); grid on;
xlabel('Cumulative 3D distance (km)'); ylabel('Speed (km/h)');
title('Synthetic ride: speed versus distance');
exportgraphics(f5, fullfile(outputFolder,'matlab_05_speed_distance.png'));

f6 = figure('Name','Power and energy');
yyaxis left; hPower = plot(elapsedSec, powerW);
ylabel('Estimated power (W)');
yyaxis right; hEnergy = plot(elapsedSec, energyJ);
ylabel('Cumulative estimated energy (J)');
legend([hPower hEnergy], {'Estimated power','Cumulative energy'}, ...
    'Location', 'best');
grid on; xlabel('Elapsed time (s)'); title('Synthetic ride: power and energy');
exportgraphics(f6, fullfile(outputFolder,'matlab_06_power_energy.png'));

fprintf('3D route length: %.3f km.\n', distanceKm(end));
fprintf('Total modelled rider energy: %.1f kJ.\n', energyJ(end)/1000);
fprintf('Six MATLAB figures saved in %s\n', outputFolder);

%% Local functions
function [lat, lon, elev, utcTimes] = readGPXTrack(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error('Unable to open GPX file: %s', filename);
    end
    cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
    lat = zeros(0,1); lon = zeros(0,1); elev = zeros(0,1);
    utcTimes = NaT(0,1,'TimeZone','UTC');
    insidePoint = false;
    currentLat = NaN; currentLon = NaN; currentElev = NaN;
    currentTime = '';
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line); continue; end
        if contains(line,'<trkpt')
            insidePoint = true;
            currentLat = NaN; currentLon = NaN; currentElev = NaN;
            currentTime = '';
            tLat = regexp(line,'lat="([^"]+)"','tokens','once');
            tLon = regexp(line,'lon="([^"]+)"','tokens','once');
            if ~isempty(tLat); currentLat = str2double(tLat{1}); end
            if ~isempty(tLon); currentLon = str2double(tLon{1}); end
        end
        if insidePoint
            tElev = regexp(line,'<ele>([^<]+)</ele>','tokens','once');
            tTime = regexp(line,'<time>([^<]+)</time>','tokens','once');
            if ~isempty(tElev); currentElev = str2double(tElev{1}); end
            if ~isempty(tTime); currentTime = tTime{1}; end
        end
        if insidePoint && contains(line,'</trkpt>')
            if ~(isfinite(currentLat) && isfinite(currentLon) && ...
                    isfinite(currentElev) && ~isempty(currentTime))
                error('One GPX track point is missing required data.');
            end
            parsedTime = datetime(currentTime, ...
                'InputFormat','yyyy-MM-dd''T''HH:mm:ss''Z''', ...
                'TimeZone','UTC');
            lat(end+1,1) = currentLat; %#ok<AGROW>
            lon(end+1,1) = currentLon; %#ok<AGROW>
            elev(end+1,1) = currentElev; %#ok<AGROW>
            utcTimes(end+1,1) = parsedTime; %#ok<AGROW>
            insidePoint = false;
        end
    end
end

function [eastM, northM, zone] = gpsToUTM(latDeg, lonDeg)
    % Standard truncated WGS84 UTM series; best for points within one zone.
    zoneEach = floor((lonDeg + 180) / 6) + 1;
    zone = zoneEach(1);
    if any(zoneEach ~= zone)
        error('This demo requires all track points in one UTM zone.');
    end
    if any(latDeg >= 84 | latDeg <= -80)
        error('UTM is not defined in this example for polar latitudes.');
    end
    a = 6378137; invF = 298.257223563;
    f = 1/invF; eSquared = f*(2-f);
    ePrimeSquared = eSquared/(1-eSquared); k0 = 0.9996;
    latRad = deg2rad(latDeg);
    lonRad = deg2rad(lonDeg);
    centralMeridianRad = deg2rad(zone*6 - 183);
    sinLat = sin(latRad); cosLat = cos(latRad);
    N = a ./ sqrt(1 - eSquared*sinLat.^2);
    T = tan(latRad).^2;
    C = ePrimeSquared*cosLat.^2;
    A = cosLat .* (lonRad - centralMeridianRad);
    e4 = eSquared^2; e6 = eSquared^3;
    meridian = a*((1-eSquared/4-3*e4/64-5*e6/256)*latRad ...
        -(3*eSquared/8+3*e4/32+45*e6/1024)*sin(2*latRad) ...
        +(15*e4/256+45*e6/1024)*sin(4*latRad) ...
        -(35*e6/3072)*sin(6*latRad));
    eastM = 500000 + k0*N.*(A + (1-T+C).*A.^3/6 + ...
        (5-18*T+T.^2+72*C-58*ePrimeSquared).*A.^5/120);
    northM = k0*(meridian + N.*tan(latRad).*(A.^2/2 + ...
        (5-T+9*C+4*C.^2).*A.^4/24 + ...
        (61-58*T+T.^2+600*C-330*ePrimeSquared).*A.^6/720));
    northM(latDeg < 0) = northM(latDeg < 0) + 10000000;
end
