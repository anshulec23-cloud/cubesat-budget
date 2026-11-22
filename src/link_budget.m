function lk = link_budget(gc, p)
%LINK_BUDGET Downlink Eb/N0 margin and daily data volume.
%   lk = LINK_BUDGET(gc, p) computes, at every time step, the received
%   Eb/N0 from the simulated slant range and compares it with the required
%   Eb/N0. Data is downlinked only while the satellite is above the minimum
%   elevation and the margin is at least p.min_margin_dB.

c     = 299792458;
k_dB  = -228.6;                                    % Boltzmann [dBW/K/Hz]
lam   = c / p.freq_Hz;

eirp_dBW = 10*log10(p.tx_power_W) + p.tx_gain_dBi - p.tx_line_loss_dB;
fspl_dB  = 20*log10(4*pi*gc.range_m / lam);
GT_dBK   = p.rx_gain_dBi - 10*log10(p.sys_noise_temp_K);

ebn0_dB  = eirp_dBW - fspl_dB - p.misc_loss_dB + GT_dBK ...
         - k_dB - 10*log10(p.data_rate_bps);
margin_dB = ebn0_dB - p.req_ebn0_dB;

usable = gc.visible & (margin_dB >= p.min_margin_dB);
downlink_bits = sum(usable) * p.dt_s * p.data_rate_bps;

lk = struct('ebn0_dB', ebn0_dB, 'margin_dB', margin_dB, 'usable', usable, ...
            'downlink_MB_per_day', downlink_bits / 8 / 1e6, ...
            'eirp_dBW', eirp_dBW, 'GT_dBK', GT_dBK);
end
