function term_reason = search(self, control_mask, varargin)
% Run the optimization.
% If control_mask is empty, try to continue the previous optimization.

if nargin < 2
    % by default update all the controls except taus
    control_mask = self.full_mask(false);
end

if isempty(control_mask)
    % continue previous optimization (re-use most of the opt struct)
    self.init_opt();
    % restore options from last run
    matlab_options = self.opt.matlab_options;
else
    % common initialization of the optimization data structures
    self.init_opt();
    self.opt.control_mask = control_mask;

    %% MATLAB-style options processing.
    % Converts a list of fieldname, value pairs in varargin to a struct.
    user_options = struct(varargin{:});

    % termination conditions and other options
    defaults = struct(...
        'error_goal',        0.5 * (1e-3)^2 / self.system.norm2,...
        'max_loop_count',    1e10,...
        'max_walltime',      1800,...
        'max_cputime',       5e5,...
        'min_gradient_norm', 1e-20,...
        'plot_interval',     1);   % how often should we plot intermediate results?

    [self.opt.options, matlab_options] = apply_options(defaults, user_options);
end

fprintf('Optimization space dimension: %d\n', sum(sum(self.opt.control_mask)));

% define the optimization problem
obj_func = @(x) goal_and_gradient_function_wrapper(self, x);

% run BFGS optimization
self.search_BFGS(obj_func, matlab_options);

term_reason = self.opt.term_reason;
end


function [err, grad] = goal_and_gradient_function_wrapper(self, x)
% x is a vector containing (a subset of) the controls

    self.opt.N_eval = self.opt.N_eval + 1;

    self.update_controls(x, self.opt.control_mask);
    [err, grad] = self.compute_error(self.opt.control_mask);
    self.opt.last_grad_norm = sqrt(sum(sum(grad .* grad)));
end


function [out, unused] = apply_options(defaults, opts)
% MATLAB-style options struct processing.
% Applies the options in the struct 'opts' to the struct 'defaults'.
% Returns the updated struct, and the struct of options that could not be parsed.

    % fields in opts
    names = fieldnames(opts);
    % logical array: are the corresponding fields present in defaults?
    present = isfield(defaults, names);

    % could not find a function for doing this
    out = defaults;
    for f = names(present).'
        out = setfield(out, f{1}, getfield(opts, f{1}));
    end
    % remove the fields we just used from opts
    unused = rmfield(opts, names(present));
end