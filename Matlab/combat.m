function bayesdata = combat(dat, batch, mod)
	batchmod = dummyvar(batch);
	n_batch = size(batchmod,2);
	levels = unique(batch);
	fprintf('[combat] Found %d batches\n', n_batch);

	batches = cell(0);
	for i=1:n_batch
		batches{i}=find(batch == levels(i));
	end
	n_batches = cellfun(@length,batches);
	n_array = sum(n_batches);

	% Creating design matrix and removing intercept:
	design = [batchmod mod];
	intercept = ones(1,n_array)';
	wh = cellfun(@(x) isequal(x,intercept),num2cell(design,1));
	bad = find(wh==1);
	design(:,bad)=[];
	fprintf('[combat] Adjusting for %d covariate(s) of covariate level(s)\n',size(design,2)-size(batchmod,2))
	fprintf('[combat] Standardizing Data across features\n')


	B_hat = inv(design'*design)*design'*dat';
	%Standarization Model
	grand_mean = (n_batches/n_array)*B_hat(1:n_batch,:);
	var_pooled = ((dat-(design*B_hat)').^2)*repmat(1/n_array,n_array,1);
	stand_mean = grand_mean'*repmat(1,1,n_array);

	if not(isempty(design))
		tmp = design;
		tmp(:,1:n_batch) = 0;
		stand_mean = stand_mean+(tmp*B_hat)';
	end	
	s_data = (dat-stand_mean)./(sqrt(var_pooled)*repmat(1,1,n_array));

	%Get regression batch effect parameters
	fprintf('[combat] Fitting L/S model and finding priors\n')
	batch_design = design(:,1:n_batch);
	gamma_hat = inv(batch_design'*batch_design)*batch_design'*s_data';
	delta_hat = [];
	for i=1:n_batch
		indices = batches{i};
		delta_hat = [delta_hat; var(s_data(:,indices)')];
	end

	%Find parametric priors:
	gamma_bar = mean(gamma_hat');
	t2 = var(gamma_hat');
	delta_hat_cell = num2cell(delta_hat,2);
	a_prior=[]; b_prior=[];
	for i=1:n_batch
		a_prior=[a_prior aprior(delta_hat_cell{i})];
		b_prior=[b_prior bprior(delta_hat_cell{i})];
	end

	fprintf('[combat] Finding parametric adjustments\n')
	gamma_star =[]; delta_star=[];
	for i=1:n_batch
		indices = batches{i};
	    temp = itSol(s_data(:,indices),gamma_hat(i,:),delta_hat(i,:),gamma_bar(i),t2(i),a_prior(i),b_prior(i), 0.001);
	    gamma_star = [gamma_star; temp(1,:)];
	    delta_star = [delta_star; temp(2,:)];
	end
	    
	fprintf('[combat] Adjusting the Data\n')
	bayesdata = s_data;
	j = 1;
	for i=1:n_batch
		indices = batches{i};
		bayesdata(:,indices) = (bayesdata(:,indices)-(batch_design(indices,:)*gamma_star)')./(sqrt(delta_star(j,:))'*repmat(1,1,n_batches(i)));
		j = j+1;
	end
	bayesdata = (bayesdata.*(sqrt(var_pooled)*repmat(1,1,n_array)))+stand_mean;

end
