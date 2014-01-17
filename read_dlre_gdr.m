function [core, lon, lat]=read_dlre_gdr(imgpath)

% Reads level 2/3 gridded .IMG files created by the Diviner 
% Lunar Radiometer Experiment (Lunar Reconnaissance Orbiter)
%
% function [core, lon, lat]=read_dlre(imgfile)
%
%Input:
%       -'infile' is the .IMG file to extract the data
%        from. The function assumes that the .LBL file is present in the
%        same directory.
%Output:
%    -'core' is a samples x lines matrix containing the core science values
%    -'lon' is a samples x lines matrix containing longitude for each pixel
%    -'lat' is a samples x lines matrix containing latitude for each pixel
%
% Date created: 23/07/2013
% Author:       Elliot Sefton-Nash
% Institution:  University of California Los Angeles
%

% Read label
lblpath = [imgpath(1:end-3),'lbl'];
lbl = read_pds_lbl(lblpath);

samples = str2double(lbl.uncompressed_file.image.line_samples);
lines = str2double(lbl.uncompressed_file.image.lines);

% Find out the precision based on passing, in this case, the value
% associated with the PDS keyword 'SAMPLE_BITS'.
[precision, pixel_bytes] = get_precision(lbl.uncompressed_file.image.sample_bits);

% Find out what byte-ordering the data is. The keyword SAMPLE_TYPE tells us
% this. For HRSC it's usually MSB_INTEGER, which is big endian.
endian = get_endian(lbl.uncompressed_file.image.sample_type);

% Open the file as binary read-only, read dns.
fid = fopen(imgpath, 'r', endian);
dn = fread(fid, [samples, lines], precision);

% Rotate by 90 degrees.
dn = dn';

fclose(fid);

% Make a mask of all the pixels equal to the null value.
null_dn = str2double(lbl.uncompressed_file.image.missing_constant);
mask = (dn ~= null_dn);

% Scale to science values:
scaling_factor = str2double(lbl.uncompressed_file.image.scaling_factor);
offset = str2double(lbl.uncompressed_file.image.offset);
core = NaN(size(dn));
core(mask) = (double(dn(mask)) * scaling_factor) + offset;

%-----LAT LON-----

switch lower(strrep(lbl.image_map_projection.map_projection_type, '"',''))
    case 'simple cylindrical'
        
        % Lat and lon have units after numbers, e.g. '<deg>'
        minlon = str2double(strrep(lbl.image_map_projection.westernmost_longitude, ' <deg>', ''));
        maxlon = str2double(strrep(lbl.image_map_projection.easternmost_longitude, ' <deg>', ''));
        
        minlat = str2double(strrep(lbl.image_map_projection.minimum_latitude, ' <deg>', ''));
        maxlat = str2double(strrep(lbl.image_map_projection.maximum_latitude, ' <deg>', ''));
        
        % Degrees per pixel in lat and lon.
        dlat = (maxlat-minlat)/(lines-1);
        dlon = (maxlon-minlon)/(samples-1);
        % lat/lon vectors.
        lat = maxlat:-1*dlat:minlat;
        lon = minlon:dlon:maxlon;
        
    case 'polar stereographic'
        % TODO figure out latlon grids for polar stereographic
        
        % Is it North or South?
        lat = NaN;
        lon = NaN;
        warning('lat and lon grids not yet readable for polar stereographic')
end