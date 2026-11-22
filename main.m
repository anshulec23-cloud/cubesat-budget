%% CubeSat Mission Budget Simulator
% Orbit, ground contact, power and link budgets for a 3U CubeSat in a
% sun-synchronous low Earth orbit, with a ground station in Mangaluru, India.
% Plain MATLAB, no toolboxes. Also runs in GNU Octave.
%
% Run:  main          (writes figures and results/summary.txt)

clear; close all; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'src'));
outdir = fullfile(here, 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end

%% Parameters (edit these)
p = struct();
% Orbit
p.altitude_m        = 500e3;
p.inclination_deg   = 97.4;      % sun-synchronous at 500 km
p.raan_deg          = 0;         % with the Sun on +X this gives beta = 0 (worst-case eclipse)
p.sun_dir_eci       = [1 0 0];
p.duration_s        = 86400;     % one day
p.dt_s              = 10;
% Ground station: Mangaluru
p.gs_lat_deg        = 12.87;
p.gs_lon_deg        = 74.84;
p.min_elevation_deg = 10;
% Power (illustrative 3U values)
p.solar_power_W     = 20;        % deployable panels, Sun-pointing
p.bus_load_W        = 4;
p.payload_load_W    = 6;
p.payload_duty      = 0.30;      % fraction of each orbit the payload is on
p.tx_load_W         = 8;         % radio while in contact
p.battery_Wh        = 40;
p.charge_eff        = 0.95;
p.discharge_eff     = 0.95;
p.soc_initial       = 1.0;
% Link: UHF downlink to a Yagi ground station
p.freq_Hz           = 437e6;
p.tx_power_W        = 1;
p.tx_gain_dBi       = 0;
p.tx_line_loss_dB   = 1;
p.rx_gain_dBi       = 14;
p.sys_noise_temp_K  = 700;
p.misc_loss_dB      = 4;         % pointing, polarisation, atmosphere
p.data_rate_bps     = 9600;
p.req_ebn0_dB       = 10.6;      % GMSK at BER 1e-5
p.min_margin_dB     = 3;
% Payload data
p.payload_data_bps  = 2000;      % while the payload is on

%% Run the budgets
orb = orbit_propagate(p);
gc  = ground_contacts(orb, p);
pw  = power_budget(orb, gc, p);
lk  = link_budget(gc, p);

ecl_sim = mean(orb.in_eclipse);
ecl_ana = eclipse_fraction_analytic(p.altitude_m, orb.beta_rad, orb.Re);

n_pass     = numel(gc.passes);
contact_s  = sum([gc.passes.duration_s]);
gen_MB     = p.payload_data_bps * p.payload_duty * p.duration_s / 8 / 1e6;
data_ratio = lk.downlink_MB_per_day / gen_MB;

%% Summary
lines = {
  sprintf('Orbit: %.0f km circular, i = %.1f deg, period %.1f min, beta %.1f deg', ...
          p.altitude_m/1e3, p.inclination_deg, orb.period_s/60, rad2deg(orb.beta_rad))
  sprintf('Eclipse fraction: simulated %.3f, analytic %.3f (difference %.3f)', ...
          ecl_sim, ecl_ana, abs(ecl_sim - ecl_ana))
  sprintf('Ground contacts over Mangaluru (el >= %d deg): %d passes, %.1f min total, longest %.1f min', ...
          p.min_elevation_deg, n_pass, contact_s/60, max([gc.passes.duration_s 0])/60)
  sprintf('Power: average generation %.2f W, average load %.2f W, margin %+.2f W', ...
          pw.avg_gen_W, pw.avg_load_W, pw.margin_W)
  sprintf('Battery: minimum state of charge %.1f %%, maximum depth of discharge %.1f %%', ...
          100*pw.min_soc, 100*pw.max_dod)
  sprintf('Link: EIRP %.1f dBW, G/T %.1f dB/K, margin %.1f dB at %d deg, %.1f dB at zenith passes', ...
          lk.eirp_dBW, lk.GT_dBK, min(lk.margin_dB(gc.visible)), p.min_elevation_deg, max(lk.margin_dB))
  sprintf('Data: %.2f MB/day downlinked vs %.2f MB/day generated (%.0f %% of payload data returned)', ...
          lk.downlink_MB_per_day, gen_MB, 100*min(data_ratio, 1))
};
fid = fopen(fullfile(outdir, 'summary.txt'), 'w');
for k = 1:numel(lines)
    fprintf('%s\n', lines{k});
    fprintf(fid, '%s\n', lines{k});
end
fclose(fid);

%% Figures
th = orb.t / 3600;   % hours

% 1. Ground track
f1 = figure('Visible', 'off');
plot(orb.lon, orb.lat, '.', 'MarkerSize', 2); hold on;
plot(orb.lon(gc.visible), orb.lat(gc.visible), 'r.', 'MarkerSize', 4);
plot(p.gs_lon_deg, p.gs_lat_deg, 'k^', 'MarkerSize', 8, 'MarkerFaceColor', 'y');
xlim([-180 180]); ylim([-90 90]); grid on;
xlabel('Longitude [deg]'); ylabel('Latitude [deg]');
title('Ground track (red: in contact with Mangaluru)');
print(f1, fullfile(outdir, 'ground_track.png'), '-dpng', '-r130');

% 2. Contacts and link margin
f2 = figure('Visible', 'off');
subplot(2,1,1);
plot(th, gc.elev_deg); hold on;
plot([0 th(end)], p.min_elevation_deg*[1 1], 'r--');
ylim([0 90]); grid on; ylabel('Elevation [deg]');
title(sprintf('Passes over Mangaluru: %d per day', n_pass));
subplot(2,1,2);
m = lk.margin_dB; m(~gc.visible) = NaN;
plot(th, m, '.'); hold on;
plot([0 th(end)], p.min_margin_dB*[1 1], 'r--');
grid on; xlabel('Time [h]'); ylabel('Link margin [dB]');
title('UHF downlink margin while in contact');
print(f2, fullfile(outdir, 'contacts_link.png'), '-dpng', '-r130');

% 3. Power and battery
f3 = figure('Visible', 'off');
subplot(2,1,1);
w = orb.t <= 3*orb.period_s;
plot(th(w), pw.gen_W(w), th(w), pw.load_W(w), 'LineWidth', 1.5); grid on;
ylim([0 1.25*p.solar_power_W]);
legend('Generated', 'Load'); ylabel('Power [W]');
title('Power over the first three orbits');
subplot(2,1,2);
plot(th, 100*pw.soc); grid on; ylim([0 100]);
xlabel('Time [h]'); ylabel('State of charge [%]');
title(sprintf('Battery state of charge (min %.1f %%)', 100*pw.min_soc));
print(f3, fullfile(outdir, 'power_battery.png'), '-dpng', '-r130');

% 4. Validation: eclipse fraction vs beta angle, simulation against closed form
raans = 0:7.5:90;
b_sim = zeros(size(raans)); e_sim = b_sim; e_ana = b_sim;
q = p; q.duration_s = 2*orb.period_s; q.dt_s = 5;
for k = 1:numel(raans)
    q.raan_deg = raans(k);
    o = orbit_propagate(q);
    b_sim(k) = rad2deg(o.beta_rad);
    e_sim(k) = mean(o.in_eclipse);
    e_ana(k) = eclipse_fraction_analytic(q.altitude_m, o.beta_rad, o.Re);
end
f4 = figure('Visible', 'off');
plot(abs(b_sim), e_ana, '-', abs(b_sim), e_sim, 'o'); grid on;
legend('Analytic (cylindrical shadow)', 'Simulated');
xlabel('|Beta angle| [deg]'); ylabel('Eclipse fraction');
title('Eclipse model check');
print(f4, fullfile(outdir, 'eclipse_validation.png'), '-dpng', '-r130');
fprintf('Eclipse check: max |simulated - analytic| over %d beta angles = %.4f\n', ...
        numel(raans), max(abs(e_sim - e_ana)));
