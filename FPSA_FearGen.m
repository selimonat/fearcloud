function [varargout]=FPSA_FearGen(varargin);
% [varargout]=FPSA_FearGen(varargin);
%
% Complete analysis and figure generation pipeline for the
% Fixation-Pattern Similarity Analysis (FPSA) manuscript. Initial versions can be
% found in Biorxiv at http://biorxiv.org/content/early/2017/04/15/125682
%
% Using this code, one can generate all results and figures presented in the manuscript.
%
% Requirements:
% ..* Matlab 2018, even though previous versions of Matlab should also work.
% ..* Relies on Fancycarp toolbox (1) for dealing with fixation data. All dependencies as
% well as raw data can be easily downloaded as a bundle from Open Science Framework
% following this link: https://osf.io/zud6h/
%
%
% Initial Setup:
% ..* First download the data from the project's OSF webpage.
% ..* After downloading the project folder from OSF, change below the PATH_PROJECT variable.
%
% Usage:
% VARARGIN sets an action related to an analysis, figure preparation or
% simple house keeping routines, such as data getters. For example,
% Some actions require input(s), these can be provided with 2nd, 3rd, and so
% forth VARARGINs. For example, 'get_fpsa_fair' action requires two
% additional input arguments i/ fixations and ii/ runs. FIXATIONS
% determines which fixations to use to compute a dissimilarity matrix and
% RUNS determine pre- or post-learning phases. By convention baseline phase
% is denoted with 2, whereas Generalization phase by 4.
%
% Examples:
% FPSA_FearGen('get_subjects') retuns the indices to participants, included
%   in the analysis. These correspond to subXXX folder numbers.
% FPSA_FearGen('get_fixmat')
%   Returns the fixation data (cached in the midlevel folder).
% FPSA_FearGen('get_trialcount',2)
%   Returns number of trials per each subject and condition for baseline
%   phase (2). Use 4 for test phase.
% FPSA_FearGen('fix_counts',fixmat) counts the fixation density on 4
%   different ROIs used in the manuscript. Get FIXMAT with FPSA_FearGen('get_fixmat')
% FPSA_FearGen('get_fixmap',fixmat,{'subject' 12 'fix' 1}) returns FDMs using FIXMAT, for
%   participant 12 and fixation index 1.
% FPSA_FearGen('get_fixmap',fixmat,{'subject' subjects 'fix' 1:100}) returns FDMs for
%   SUBJECTS and fixations from 1 to 100 (well, basically all the
%   fixations). Each FDM is a column vector.
% FPSA_FearGen('plot_ROIs') plots the ROIs.
% FPSA_FearGen('get_fpsa',1:100) would return the dissimilarity matrix
%   computed with exploration patterns containing all the fixations
%   (1:100). This is not a recommended method for computing dissimilarity
%   matrices, rather use:
% FPSA_FearGen('get_fpsa_fair',{'fix',1:100},1:3) which would compute a fair
%   dissimilarity matrix for each run separately. 3 runs in generalization
%   are averaged later.
%
%
%
% Contact: sonat@uke.de; l.kampermann@uke.de

%% Set the default parameters
path_project         = sprintf('%s%s',homedir,'/Documents/Experiments/project_FPSA_FearGen/');% location of the project folder (MUST END WITH A FILESEP);
condition_borders    = {'' 1:8 '' 9:16};                                    % baseline and test condition labels.
block_extract        = @(mat,y,x,z) mat((1:8)+(8*(y-1)),(1:8)+(8*(x-1)),z); % a little routing to extract blocks from RSA maps
tbootstrap           = 1000;                                                % number of bootstrap samples
method               = 'correlation';                                       % methods for RSA computation
current_subject_pool = 0;                                                   % which subject pool to use (see get_subjects)
runs                 = 1:3;                                                 % which runs of the test phase to be used
criterion            ='strain' ;                                            % criterion for the MDS analysis.
force                = 0;                                                   % force recaching of results.
kernel_fwhm          = 37*0.8;                                               % size of the smoothing window (.8 degrees by default);
random_noise         = 1;                                                   % should fixation maps be slightly added with noise.
url                  = 'https://www.dropbox.com/s/0wix64zy2dlwh8g/project_FPSA_FearGen.tar.gz?dl=1';
%% overwrite default parameters with the input
invalid_varargin = logical(zeros(1,length(varargin)));
for nf = 1:length(varargin)
    if strcmp(varargin{nf}     , 'tbootstrap')
        tbootstrap           = varargin{nf+1};
    elseif strcmp(varargin{nf} , 'method')
        method               = varargin{nf+1};
    elseif strcmp(varargin{nf} , 'current_subject_pool')
        current_subject_pool = varargin{nf+1};
    elseif strcmp(varargin{nf} , 'runs')
        runs                 = varargin{nf+1};
    elseif strcmp(varargin{nf} , 'criterion')
        criterion            = varargin{nf+1};
    elseif strcmp(varargin{nf} , 'force')
        force                = varargin{nf+1};
    elseif strcmp(varargin{nf} , 'kernel_fwhm')
        kernel_fwhm          = varargin{nf+1};
    else
        invalid_varargin(nf) = true;%detect which varargins modify the default values and delete them
    end
end
varargin([find(~invalid_varargin) find(~invalid_varargin)+1]) = [];%now we have clean varargin cellarray we can continue

%%
if strcmp(varargin{1},'get_subjects'); %% returns subject indices based on the CURRENT_SUBJECT_POOL variable.
    %%
    % For the paper we use current_pool = 0, which discards all subjects:
    % who are not calibrated good enough
    %
    % Results are cached, use FORCE = 1 to recache. Set
    % CURRENT_SUBJECT_POOL = 0 to not select participants.
    
    filename = sprintf('%s/data/midlevel/subjectpool_%03d.mat',path_project,current_subject_pool);
    if exist(filename) == 0 | force
        if current_subject_pool == 0;
            subjects = Project.subjects(Project.subjects_ET);
        elseif current_subject_pool == 1%find tuned people;
            
            fprintf('finding tuned subjects first...\n');
            p=[];sub=[];pval=[];
            for n = Project.subjects(Project.subjects_ET);
                s    = Subject(n);
                s.fit_method = 8;%mobile vonMises function;
                p    = [p    ; s.get_fit('rating',4).params];
                pval = [pval ; s.get_fit('rating',4).pval];
                sub  = [sub  ; n];
            end
            valid    = (abs(p(:,3)) < 45) & pval > -log10(.05);%selection criteria
            fprintf('Found %03d valid subjects...\n',sum(valid));
            subjects = sub(valid);
            save(filename,'subjects');
        end
    else
        load(filename);
    end
    varargout{1} = subjects;
    allsubs      = Project.subjects(Project.subjects_ET);
    varargout{2} = allsubs(~ismember(allsubs,subjects));
elseif strcmp(varargin{1},'get_trialcount') %% Sanity check for number of trials per subject.
    %%
    % goes through subjects and counts the number of trials in a PHASE. The
    % output is [subjects conditions].
    % VARARGIN{2}.
    %
    % Example: FPSA_FearGen('get_trialcount',4) for phase 4 (test phase).
    % Example: FPSA_FearGen('get_trialcount',2) for phase 4 (test phase).
    phase  = varargin{2};
    fixmat = FPSA_FearGen('get_fixmat');
    s      = 0;
    for ns = unique(fixmat.subject)
        s = s+1;
        c = 0;
        for nc = unique(fixmat.deltacsp)
            c = c+1;
            C(s,c) = (length(unique(fixmat.trialid(fixmat.subject == ns & fixmat.deltacsp == nc & fixmat.phase == phase))));
        end
    end
    varargout{1} = C;
    imagesc(C(:,1:8));
    ylabel('participants')
    xlabel('conditions')
    title(sprintf('Number of trials for phase %d',phase));
    colorbar;
elseif strcmp(varargin{1},'get_fixmat'); %% load the fixation data in the form of a Fixmat.
    %%
    %   For more information on Fixmat structure refer to (1), where this
    %   data is also published.
    %   Will return fixmat for the baseline and test phases. Generalization
    %   phase has 3 runs, by default all are returned. Use
    %           fixmat   = FPSA_FearGen('get_fixmat','runs',run);
    %   to return the required run. For example FPSA_Fair uses this method
    %   to compute a separate FPSA on separate runs.
    %
    %
    %   Use force = 1 to recache (defined at the top).
    %
    %   Example: fixmat = FPSA_FearGen('get_fixmat')
    
    filename = sprintf('%s/data/midlevel/fixmat_subjectpool_%03d_runs_%03d_%03d.mat',path_project,current_subject_pool,runs(1),runs(end));
    fix      = [];
    if exist(filename) == 0 | force
        subjects = FPSA_FearGen('current_subject_pool',current_subject_pool,'get_subjects');
        fix      = Fixmat(subjects,[2 4]);%all SUBJECTS, PHASES and RUNS
        %further split according to runs if wanted.
        valid    = zeros(1,length(fix.x));
        runs
        for run = runs(:)'
            valid = valid + ismember(fix.trialid , (1:120)+120*(run-1))&ismember(fix.phase,4);%run selection opeates only for phase 4
        end
        %we dont want to discard phase02 fixations
        valid    = valid + ismember(fix.phase,2);
        fix.replaceselection(valid);
        fix.ApplySelection;
        save(filename,'fix');
    else
        load(filename)
    end
    fix.kernel_fwhm = kernel_fwhm;
    varargout{1}    = fix;
elseif strcmp(varargin{1},'fix_counts') %% Sanity check: counts fixations in 5 different ROI
    %%
    %during baseline and generalization, returns [subjects, roi, phase].
    fixmat         = varargin{2};
    fixmat.unitize = 0;
    subjects       = unique(fixmat.subject);
    c = 0;
    for ns = subjects(:)'
        fprintf('Counting fixations in subject: %03d.\n',ns)
        c = c+1;
        p = 0;
        for phase = [2 4]
            p = p +1;
            fixmat.getmaps({'phase' phase 'subject' ns});
            dummy        = fixmat.maps;
            count(c,:,p) = fixmat.EyeNoseMouth(dummy,0);
        end
    end
    varargout{1} = count;
elseif  strcmp(varargin{1},'get_fixmap') %% General routine to compute a FDMs i.e. probability of fixation as a function of space.
    %%
    %   Always returns 16 maps, 8 per baseline and generalization phases.
    %   By default uses all the fixations available in the FIXMAT provided
    %   in the first VARARGIN. The second VARARGIN is a selector cell array
    %   as it is understood by the fixmat object.
    %
    % FDMs for a SUBJECT, recorded at both phases for fixations FIX (vector) based on a FIXMAT.
    % maps are mean corrected for each phase separately.
    fixmat  = varargin{2};
    selector= varargin{3};
    %create the query cell to talk to Fixmat object
    maps    = [];
    for phase = [2 4];
        v    = [];
        c    = 0;
        for cond = -135:45:180
            c    =  c+1;
            v{c} = {'phase', phase, 'deltacsp' cond selector{:}};
        end
        fixmat.getmaps(v{:});%real work done by the fixmat object.
        maps = cat(2,maps,demean(fixmat.vectorize_maps')');%within phase mean subtraction
    end
    varargout{1} = maps;
    
elseif strcmp(varargin{1},'plot_fdm'); %% plot routine for FDMs used in the paper in a similar way to Figure 3A.
    %%
    % Use the second VARARGIN to plot ROIs on top.
    % VARARGIN{1} contains fixation maps in the form of [x,y,condition].
    % The output of FPSA_FearGen('get_fixmap',...) has to be accordingly
    % reshaped. size(VARARGIN{1},3) must be a multiple of 8.
    maps          = varargin{2};
    tsubject      = size(maps,3)/8;
    contour_lines = 1;%FACIAL ROIs Plot or not.
    fs            = 18;%fontsize;
    if nargin == 3
        contour_lines = varargin{3};
    end
    %     grids         = [linspace(prctile(fixmat.maps(:),0),prctile(fixmat.maps(:),10),10) linspace(prctile(fixmat.maps(:),90),prctile(fixmat.maps(:),100),10)];
    %     [d u]         = GetColorMapLimits(maps(:),2.5);
    %     grids         = [linspace(d,u,5)];
    t             = repmat(circshift({'CS+' '+45' '+90' '+135' ['CS' char(8211)] '-135' '-90' '-45'},[1 3]),1,tsubject);
    colors        = GetFearGenColors;
    colors        = repmat(circshift(colors(1:8,:),0),tsubject,1);
    colormap jet;
    %%
    for n = 1:size(maps,3)
        if mod(n-1,8)+1 == 1;
            figure;set(gcf,'position',[1952 361 1743 714]);
        end
        hhhh(n)=subplot(1,8,mod(n-1,8)+1);
        imagesc(Fixmat([],[]).stimulus);
        hold on
        grids         = linspace(min(Vectorize(maps(:))),max(Vectorize(maps(:))),21);
        [a,h2]        = contourf(maps(:,:,n),grids,'color','none');
        caxis([grids(2) grids(end)]);
        %if n == 8
        %h4 = colorbar;
        %set(h4,'box','off','ticklength',0,'ticks',[[grids(4) grids(end-4)]],'fontsize',fs);
        %end
        hold off
        axis image;
        axis off;
        if strcmp(t{mod(n-1,8)+1}(1),'+') | strcmp(t{mod(n-1,8)+1}(1),'-')
            h= title(sprintf('%s%c',t{mod(n-1,8)+1},char(176)),'fontsize',fs,'fontweight','normal');
        else
            h= title(sprintf('%s',t{mod(n-1,8)+1}),'fontsize',fs,'fontweight','normal');
        end
        try
            h.Position = h.Position + [0 -50 0];
        end
        %
        drawnow;
        pause(.5);
        %
        try
            %%
            %             I      = find(ismember(a(1,:),h2.LevelList));
            %             [~,i]  = max(a(2,I));
            %             alphas = [repmat(.5,1,length(I))];
            %             alphas(i) = 0;
            contourf_transparency(h2,.75);
        end
        %%
        rectangle('position',[0 0 diff(xlim) diff(ylim)],'edgecolor',colors(mod(n-1,8)+1,:),'linewidth',7);
    end
    pause(1);
    for n = 1:size(maps,3);
        subplotChangeSize(hhhh(n),.01,.01);
    end
    
    if contour_lines
        hold on;
        rois = Fixmat([],[]).GetFaceROIs;
        for n = 1:4
            contour(rois(:,:,n),'k--','linewidth',1);
        end
    end
elseif strcmp(varargin{1},'plot_ROIs'); %simple routine to plot ROIs on a face
    %%
    fix = Fixmat([],[]);
    rois = fix.GetFaceROIs;
    rois(:,:,1) = sum(rois(:,:,1:2),3);
    rois(:,:,2:3) = rois(:,:,3:4);
    rois(:,:,end) = [];
    for n = 1:3
        figure(n);
        imagesc(fix.stimulus);
        axis image;
        axis off;
        hold on;
        %         h = imagesc(ones(size(fix.stimulus,1),size(fix.stimulus,1)),[0 1]);
        %         h.AlphaData =rois(:,:,n)./2;
        contour(rois(:,:,n),'k-','linewidth',4);
        hold off;
       
       % SaveFigure(sprintf(%s/data/midlevel/figures/ROIs.png',path_project));
       
    end
elseif strcmp(varargin{1},'get_fpsa_timewindowed') %% Computes FPSA matrices for different time-windows
    %%
    %Time windows are computed based on WINDOW_SIZE and WINDOW_OVERLAP.
    %WINDOWN_OVERLAP must be equal to WINDOW_SIZE to conduct the analysis
    %on non-overlapping segments.
    %
    %Example usage:
    %[sim,model] = FPSA_FearGen('get_fpsa_timewindowed',500,500);
    %
    %model.w contains weights for the linear model as
    %[subjects,phase,model,param,time]
    %
    %Note:
    % I hacked this routine to compute FPSA fixation by fixation.
    % use it like:
    % [sim,model] = FPSA_FearGen('get_fpsa_timewindowed',1,1);
    % or [sim,model] = FPSA_FearGen('get_fpsa_timewindowed',0,1);
    
    
    
    %
    window_size    = varargin{2};
    window_overlap = varargin{3};%this is actually not an overlap, but distance between start points
    hash           = DataHash(varargin);
    
    if window_size > 10
        t              = 0:1:(window_size-1);%running window
        start_times    = 1:window_overlap:1500-window_size+1;%in milliseconds
        time           = repmat(start_times',1,length(t)) + repmat(t,length(start_times),1)
    else
        t              = 0:1:(window_size);%running window
        if window_size == 0
            start_times    = 1:window_overlap:5;%in fixation indices
        else
            start_times    = 1:window_overlap:4;%in fixation indices
        end
        time           = repmat(start_times',1,length(t)) + repmat(t,length(start_times),1);
    end
    
    filename       = sprintf('%s/data/midlevel/fpsa_timewindowed_subjectpool_%03d_kernel_fwhm_%03d_runs_%s_input_%s.mat',path_project,current_subject_pool,kernel_fwhm,mat2str(runs),hash);
    if exist(filename) == 0 | force
        fprintf('Has %d time windows in total...\n',size(time,1));
        %
        fixmat          = FPSA_FearGen('current_subject_pool',current_subject_pool,'force',force,'kernel_fwhm',kernel_fwhm,'get_fixmat');
        sim.correlation = nan(length(unique(fixmat.subject)),120,size(time,1));
        %
        tc = 0;
        for t = 1:size(time,1)
            fprintf('Processing window %d of %d time windows...\n',t,size(time,1));
            tc                   = tc+1;
            if window_size > 10
                dummy                = FPSA_FearGen('current_subject_pool',current_subject_pool,'force',force,'kernel_fwhm',kernel_fwhm,'get_fpsa_fair',{'start' time(t,:)},1:3);
            else
                dummy                = FPSA_FearGen('current_subject_pool',current_subject_pool,'force',force,'kernel_fwhm',kernel_fwhm,'get_fpsa_fair',{'fix' time(t,:)},1:3);
            end
            sim.(method)(:,:,tc) = dummy.correlation;
            T                    = FPSA_FearGen('FPSA_sim2table',dummy);
            [~, C.w(:,:,:,:,tc)] = FPSA_FearGen('FPSA_model_singlesubject',T.t);
            
        end
        save(filename,'C','sim')
    else
        load(filename);
    end
    
    C.t               = time;
    varargout{1}      = sim;
    varargout{2}      = C;
    
    %%
    figure;
    model = C;
    h(1)=subplot(2,2,1);
    hold off;%plot(model.t,squeeze(nanmean(model.w(:,1,1,1,:))),'b',model.t,squeeze(nanmean(model.w(:,2,1,1,:))),'r');
    H2= shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,1,1,1,:)))',squeeze(nanSEM(model.w(:,1,1,1,:)))','lineprops','b');hold on;
    H1=shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,2,1,1,:))),squeeze(nanSEM(model.w(:,2,1,1,:))),'lineprops','r');box off;axis tight;ylim([-.05 0.2]);xlim([min(C.t(:,1)) max(C.t(:,1))]);
    xtick={};for ntik = 1:size(model.t,1);xtick = [xtick sprintf('%d-%d',min(model.t(ntik,:)),max(model.t(ntik,:)))];end
    set(gca,'xtick',model.t(:,1),'xticklabel',{''},'XTickLabelRotation',45,'fontsize',12,'xgrid','on','ygrid','on')
    title('circular W model 1');
    %
    h(2)=subplot(2,2,2);hold off;
    H2= shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,2,2,1,:)-model.w(:,1,2,1,:))),squeeze(nanSEM(model.w(:,2,2,1,:)-model.w(:,1,2,1,:))),'lineprops','r');hold on;
    H1= shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,2,2,2,:)-model.w(:,1,2,2,:))),squeeze(nanSEM(model.w(:,2,2,2,:)-model.w(:,1,2,2,:))),'lineprops','b');box off;axis tight;ylim([-.05 0.2]);xlim([min(C.t(:,1)) max(C.t(:,1))]);
    title('Generalization - Baseline');
    set(gca,'xtick',model.t(:,1),'xticklabel',{''},'XTickLabelRotation',45,'fontsize',12,'xgrid','on','ygrid','on')
    H2.mainLine.LineWidth = 1.5;H2.mainLine.LineWidth = 1.5;H2.mainLine.Color = [1 0 0 .5];H1.mainLine.LineWidth = 1.5;H1.mainLine.Color = [0 0 1 .5];
    %
    h(3)=subplot(2,2,3);hold off;%plot(model.t,squeeze(nanmean(model.w(:,2,2,1,:))),'b',model.t,squeeze(nanmean(model.w(:,2,2,2,:))),'r',model.t,squeeze(nanmean(model.w(:,1,2,1,:))),'b--',model.t,squeeze(nanmean(model.w(:,1,2,2,:))),'r--');
    H2=shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,1,2,1,:)))',squeeze(nanSEM(model.w(:,1,2,1,:)))','lineprops','r-');hold on;
    H1=shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,1,2,2,:))),squeeze(nanSEM(model.w(:,1,2,2,:))),'lineprops','b-');box off;axis tight;ylim([-0.02 0.2]);xlim([min(C.t(:,1)) max(C.t(:,1))]);
    if size(model.t(:,1),1) < 10
        set(gca,'xtick',model.t(:,1),'xticklabel',xtick,'XTickLabelRotation',0,'fontsize',12,'xgrid','on','ygrid','on','ytick',[0 .1 .2],'fontsize',12,'fontweight','normal');
    else
        xtick = {(model.t(1:5:end,end)+model.t(1:5:end,1)-1)/2};
        set(gca,'xtick',model.t(1:5:end,1),'xticklabel',xtick(1:5:end),'XTickLabelRotation',0,'xgrid','on','ygrid','on','ytick',[0 .1 .2],'fontsize',12,'fontweight','normal');
    end
    
    
    H2.mainLine.LineWidth = 2;H2.mainLine.Color = [1 0 0 .5];H1.mainLine.LineWidth = 2;H1.mainLine.Color = [0 0 1 .5];
    
    title('Baseline','fontsize',18);
    hl = legend([H2.mainLine H1.mainLine],{'w_{specific}' 'w_{unspecific}'})
    hl.FontSize = 12;
    legend boxoff
    if size(model.t(:,1),1) < 10
        xlabel('fixations','fontweight','bold','fontsize',16);
    else
        xlabel('time window  (ms)','fontweight','bold','fontsize',16);
    end
    ylabel('weight','fontweight','bold','fontsize',16)
    grid on
    %
    h(4)=subplot(2,2,4);hold off;%plot(model.t,squeeze(nanmean(model.w(:,2,2,1,:))),'b',model.t,squeeze(nanmean(model.w(:,2,2,2,:))),'r',model.t,squeeze(nanmean(model.w(:,1,2,1,:))),'b--',model.t,squeeze(nanmean(model.w(:,1,2,2,:))),'r--');
    H2=shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,2,2,1,:)))',squeeze(nanSEM(model.w(:,2,2,1,:)))','lineprops','r');hold on;
    H1=shadedErrorBar(model.t(:,1),squeeze(nanmean(model.w(:,2,2,2,:))) ,squeeze(nanSEM(model.w(:,2,2,2,:))) ,'lineprops','b');box off;axis tight;ylim([-0.02 0.2]);xlim([min(C.t(:,1)) max(C.t(:,1))]);
    H2.mainLine.LineWidth = 2;H2.mainLine.Color = [1 0 0 .5];H1.mainLine.LineWidth = 2;H1.mainLine.Color = [0 0 1 .5];
    set(gca,'yticklabels',[]);
    
    if size(model.t(:,1),1) < 10
        set(gca,'xtick',model.t(:,1),'xticklabel',xtick,'XTickLabelRotation',0,'fontsize',12,'xgrid','on','ygrid','on','ytick',[0 .1 .2],'fontsize',12,'fontweight','normal');
    else
        set(gca,'xtick',model.t(1:5:end,1),'xticklabel',xtick(1:5:end),'XTickLabelRotation',0,'xgrid','on','ygrid','on','ytick',[0 .1 .2],'fontsize',12,'fontweight','normal');
    end
    if size(model.t(:,1),1) < 10
        xlabel('fixations','fontweight','bold','fontsize',16);
    else
        ggg=xlabel('time window (ms)','fontweight','bold','fontsize',16);
    end
    subplotChangeSize(h,.02,.02);
    title('Generalization','fontsize',18);
    set(gcf,'position',[2034         402 900 900]);
    %% find significant time points
    whichtest = 'ttest';
    alpha = 0.05;
    %[subjects,phase,model,param,time]
    X = squeeze(   (model.w(:,2,2,1,:)-model.w(:,2,2,2,:)) - (model.w(:,1,2,1,:)-model.w(:,1,2,2,:)) )     %difference between curves
    %     X = squeeze(   (model.w(:,2,2,1,:)-model.w(:,2,2,2,:)) )
    if strcmp(whichtest,'signrank')
        for i = 1:size(X,2)
            [PP(i) HH(i)] = signrank(X(:,i));
        end
    elseif strcmp(whichtest,'ttest')
        size(X)
        [HH PP] = ttest(X,[]); %tests difference spec > unspec
        PP
    end
    hold on
    for n = 1:size(X,2)
        if PP(n) <= .05
            n
            text(model.t(n,1),max(ylim)-.01,'*','HorizontalAlignment','center','fontsize',20);
        end
    end
    
    sort(model.t(find(PP < alpha))-window_size)
    %%
    %     SaveFigure('~/Dropbox/feargen_lea/manuscript/figures/figure_04.png','-transparent','-r300');
    
elseif strcmp(varargin{1},'get_fpsa_fair') %% Computes FPSA separately for each run and single subjects
    %%
    % FPSA for the 3 test-phase runs are individually computed and averaged.
    % Doing it the other way (i.e. average FDMs from the 3 phases and compute
    % FPSA as in get_fpsa) would have led to comparably less noisy FDMs for the test
    % phase and thus differences btw B and T simply because the number of
    % trials are different. See (4) for more information on how noise
    % affects similarity values.
    %
    % Example usage:
    % sim = FPSA_FearGen('get_fpsa_fair',{'fix',1:100},1:3);
    
    selector = varargin{2};%which fixations
    runs     = varargin{3};%whichs runs would you like to have
    hash     = DataHash(selector);
    fprintf('===================\n')
    selector
    hash
    fprintf('===================\n')
    %
    filename     = sprintf('%s/data/midlevel/fpsa_fair_kernel_fwhm_%03d_subjectpool_%03d_runs_%s_selector_%s.mat',path_project,kernel_fwhm,current_subject_pool,mat2str(runs),hash);
    if exist(filename) ==0 | force;
        runc = 0;
        for run = runs %these are parts of phase 4 runs (1-2-3), not phases per se
            runc     = runc+1;
            fixmat   = FPSA_FearGen('current_subject_pool',current_subject_pool,'kernel_fwhm',kernel_fwhm,'runs',run,'get_fixmat');
            subc     = 0;
            for subject = unique(fixmat.subject);
                subc                    = subc + 1;
                maps                    = FPSA_FearGen('get_fixmap',fixmat,{'subject' subject,selector{:}}); %this gives 16 fixmaps, [8condsBaseline 8condsTestphase]
                fprintf('Subject: %03d, Run: %03d, Method: %s\n',subject,run,method);
                sim.(method)(subc,:,runc)= pdist(maps',method);% %length 120, triangular form of 16*16 matrix
            end
        end
        %average across runs
        sim.(method) = mean(sim.(method),3);
        save(filename,'sim');
    else
        load(filename);
    end
    
    varargout{1} = sim;
    
elseif strcmp(varargin{1},'plot_fpsa');%% A routine to plot similarity matrices
    %%
    figure;
    sim     = varargin{2};
    cormatz = squareform(nanmean(sim.correlation));
    cormatz = CancelDiagonals(cormatz,NaN);
    [d u]   = GetColorMapLimits(cormatz,2.5);
    imagesc(cormatz,[d u]);
    axis square;colorbar
    set(gca,'fontsize',15);
    axis off;
elseif strcmp(varargin{1},'get_block') %% will get the Yth, Xth block from similarity matrix SIM.
    %%
    % SQFM is the square_form of SIM.
    %
    % Example: fpsa = FPSA_FearGen('get_block',FPSA_FearGen('get_fpsa',1:100),2,2)
    sim  = varargin{2};
    y    = varargin{3};
    x    = varargin{4};
    r    = [];
    sqfm = [];
    for ns = 1:size(sim.correlation,1)
        dummy = squareform(sim.correlation(ns,:));
        B     = block_extract(dummy,y,x,1);%funhandle defined at the top.
        r     = cat(3,r,B);
        sqfm  = [sqfm;squareform(B)];
    end
    varargout{1} = r;
    varargout{2} = sqfm;
elseif strcmp(varargin{1},'get_mdscale') %% Routine to make MDS analysis using a SIMilarity matrix with NDIMENsions.
    %%
    %
    % Example: FPSA_FearGen('get_mdscale',mean(sim.correlation),2);
    sim                         = varargin{2};%sim is a valid similarity matrix;
    ndimen                      = varargin{3};
    viz                         = 1;
    [dummy stress disparities]  = mdscale(sim,ndimen,'Criterion',criterion,'start','cmdscale','options',statset('display','final','tolfun',10^-12,'tolx',10^-12));
    dummy                       = dummy';
    Y                           = dummy(:);
    varargout{1}                = Y;
    if viz
        FPSA_FearGen('plot_mdscale',Y);
    end
elseif strcmp(varargin{1},'plot_mdscale') %% Routine to plot the results of the get_mdscale
    %%
    Y      = varargin{2};
    ndimen = length(Y)./16;
    y      = reshape(Y,length(Y)/16,16)';%to make it easy plotting put coordinates to different columns;
    colors = GetFearGenColors;
    colors = [colors(1:8,:);colors(1:8,:)];
    if ndimen == 2
        plot(y([1:8 1],1),y([1:8 1],2),'.-.','linewidth',3,'color',[.6 .6 .6]);
        hold on;
        plot(y([1:8 1]+8,1),y([1:8 1]+8,2),'k.-.','linewidth',3);
        for nface = 1:16
            plot(y(nface,1),y(nface,2),'.','color',colors(nface,:),'markersize',120,'markerface',colors(nface,:));
        end
        hold off;
        %
        for n = 1:16;text(y(n,1),y(n,2),mat2str(mod(n-1,8)+1),'fontsize',25);end
    elseif ndimen == 3
        plot3(y([1:8 1],1),y([1:8 1],2),y([1:8 1],3),'o-','linewidth',3);
        hold on;
        plot3(y([1:8 1]+8,1),y([1:8 1]+8,2),y([1:8 1]+8,3),'ro-','linewidth',3);
        hold off;
        for n = 1:16;text(y(n,1),y(n,2),y(n,3),mat2str(mod(n-1,8)+1),'fontsize',25);end
    end
elseif strcmp(varargin{1},'FPSA_get_table') %% returns a table object ready for FPSA modelling with fitlm, fitglm, etc.
    %%
    %
    % This action returns all dependent and independent variables
    % necessary for the modelling in a neat table format.
    %
    % the table object contains the following variable names:
    % FPSA_B     : similarity matrices from baseline.
    % FPSA_G     : similarity matrices from test.
    % circle     : circular predictor consisting of a sum of specific and
    % unspecific components.
    % specific   : specific component based on quadrature decomposition
    % (the cosine factor).
    % unspecific : unspecific component based on quadrature decomposition
    % (the sine factor).
    % Gaussian   : generalization of the univariate Gaussian component to
    % the similarity space.
    % subject    : indicator variable for subjects
    % phase      : indicator variable for baseline and generalizaation
    % phases.
    %
    % Example: FPSA_FearGen('FPSA_get_table',{'fix' 1:100})
    selector  = varargin{2};
    hash      = DataHash(selector);
    filename  = sprintf('%s/data/midlevel/fpsa_modelling_table_subjectpool_%03d_runs_%02d_%02d_selector_%s.mat',path_project,current_subject_pool,runs(1),runs(end),hash);
    if ~exist(filename) | force
        %the full B and T similarity matrix which are jointly computed;
        sim       = FPSA_FearGen('get_fpsa_fair',selector,runs);%returns FPSA per subject
        %%we only want the B and T parts
        B         = FPSA_FearGen('get_block',sim,1,1); %8x8x74
        T         = FPSA_FearGen('get_block',sim,2,2);
        %once we have these, we go back to the compact form and concat the
        %stuff, now each column is a non-redundant FPSA per subject
        for n = 1:size(sim.correlation,1)
            BB(n,:) = squareform(B(:,:,n));
            TT(n,:) = squareform(T(:,:,n));
        end
        BB       = BB';
        TT       = TT';
        % gives us column vectors with dissimilarities of each subject for
        % B and for T , size 120
        
        % some indicator variables for phase, subject identities.
        phase    = repmat([repmat(1,size(BB,1)/2,1); repmat(2,size(BB,1)/2,1)],1,size(BB,2));
        subject  = repmat(1:size(sim.correlation,1),size(BB,1),1);
        S        = subject(:);
        P        = phase(:);
        %% our models:
        %MODEL1: perfectly circular similarity model;
        %MODEL2: flexible circular similarity model;
        %MODEL3: Model2 + a Gaussian.
        % a circular FPSA matrix for B and T replicated by the number of subjects
        x          = [pi/4:pi/4:2*pi];
        w          = [cos(x);sin(x)];
        model1     = repmat(repmat(squareform_force(w'*w),1,1),1,size(subject,2));%we use squareform_force as the w'*w is not perfectly positive definite matrix due to rounding errors.
        %
        model2_c   = repmat(repmat(squareform_force(cos(x)'*cos(x)),1,1),1,size(subject,2));%
        model2_s   = repmat(repmat(squareform_force(sin(x)'*sin(x)),1,1),1,size(subject,2));%
        %
        %getcorrmat(amp_circ, amp_gau, amp_const, amp_diag, varargin)
        [cmat]     = getcorrmat(0,3,1,1);%see model_rsa_testgaussian_optimizer
        model3_g   = repmat(repmat(squareform_force(cmat),1,1),1,size(subject,2));%
        %% add all this to a TABLE object.
        t          = table(1-BB(:),1-TT(:),model1(:),model2_c(:),model2_s(:),model3_g(:),categorical(subject(:)),categorical(phase(:)),'variablenames',{'FPSA_B' 'FPSA_G' 'circle' 'specific' 'unspecific' 'Gaussian' 'subject' 'phase'}); %this phase category is corrupt.
        save(filename,'t');
    else
        load(filename);
    end
    varargout{1} = t;
elseif strcmp(varargin{1},'FPSA_sim2table'); %% subroutine to transform a FPSA matrix to a table for modelling
    %%
    tsubject        = size(varargin{2}.correlation,1);
    predictor_table = repmat(FPSA_FearGen('FPSA_predictortable'),tsubject,1);
    for n_level = 1:size(varargin{2}.correlation,3)
        sim.correlation  = varargin{2}.correlation(:,:,n_level);
        B                = FPSA_FearGen('get_block',sim,1,1);
        T                = FPSA_FearGen('get_block',sim,2,2);
        %once we have these, we go back to the compact form and concat the
        %stuff, now each column is a non-redundant FPSA per subject
        BB=[];TT=[];
        for n = 1:size(sim.correlation,1)
            BB(n,:) = squareform(B(:,:,n));
            TT(n,:) = squareform(T(:,:,n));
        end
        BB               = BB';
        TT               = TT';
        % some indicator variables for phase, subject identities.
        phase            = repmat([repmat(1,size(BB,1)/2,1); repmat(2,size(BB,1)/2,1)],1,size(BB,2));
        subject          = repmat(1:size(sim.correlation,1),size(BB,1),1);
        
        dummy(n_level).t = [predictor_table table(1-BB(:),1-TT(:),categorical(subject(:)),categorical(phase(:)),'variablenames',{'FPSA_B' 'FPSA_G' 'subject' 'phase'})];
    end
    %% will now add the predictors to the table
    varargout{1} = dummy;
elseif strcmp(varargin{1},'FPSA_predictortable');
    %% returns the basic predictors as a table
    x            = [pi/4:pi/4:2*pi];
    w            = [cos(x);sin(x)];
    model1       = squareform_force(w'*w);%we use squareform_force as the w'*w is not perfectly positive definite matrix due to rounding errors.
    %
    model2_c     = squareform_force(cos(x)'*cos(x));%
    model2_s     = squareform_force(sin(x)'*sin(x));%
    %
    %getcorrmat(amp_circ, amp_gau, amp_const, amp_diag, varargin)
    [cmat]       = getcorrmat(0,3,1,1);%see model_rsa_testgaussian_optimizer
    model3_g     = squareform_force(cmat);%
    % add all this to a TABLE object.
    varargout{1} = table(model1(:),model2_c(:),model2_s(:),model3_g(:),'variablenames',{'circle' 'specific' 'unspecific' 'Gaussian' });
elseif strcmp(varargin{1},'FPSA_model'); %% models FPSA matrices with mixed and fixed models.
    %%
    selector   = varargin{2};
    t          = FPSA_FearGen('runs',runs,'FPSA_get_table',selector);
    % MIXED EFFECT MODEL
    % null model
    out.baseline.model_00_mixed          = fitlme(t,'FPSA_B ~ 1 + (1|subject)');
    out.generalization.model_00_mixed    = fitlme(t,'FPSA_G ~ 1 + (1|subject)');
    % FPSA_model_bottom-up model
    out.baseline.model_01_mixed          = fitlme(t,'FPSA_B ~ 1 + circle + (1 + circle|subject)');
    out.generalization.model_01_mixed    = fitlme(t,'FPSA_G ~ 1 + circle + (1 + circle|subject)');
    % FPSA_model_adversitycateg
    out.baseline.model_02_mixed          = fitlme(t,'FPSA_B ~ 1 + specific + unspecific +  (1 + specific + unspecific|subject)');
    out.generalization.model_02_mixed    = fitlme(t,'FPSA_G ~ 1 + specific + unspecific +  (1 + specific + unspecific|subject)');
    % FPSA_model_adversitytuning
    out.baseline.model_03_mixed          = fitlme(t,'FPSA_B ~ 1 + specific + unspecific + Gaussian + (1 + specific + unspecific + Gaussian|subject)');
    out.generalization.model_03_mixed    = fitlme(t,'FPSA_G ~ 1 + specific + unspecific + Gaussian + (1 + specific + unspecific + Gaussian|subject)');
    %% FIXED EFFECT MODEL
    % FPSA null model
    out.baseline.model_00_fixed          = fitlm(t,'FPSA_B ~ 1');
    out.generalization.model_00_fixed    = fitlm(t,'FPSA_G ~ 1');
    % FPSA_model_bottom-up model
    out.baseline.model_01_fixed          = fitlm(t,'FPSA_B ~ 1 + circle');
    out.generalization.model_01_fixed    = fitlm(t,'FPSA_G ~ 1 + circle');
    % FPSA_model_adversitycateg
    out.baseline.model_02_fixed          = fitlm(t,'FPSA_B ~ 1 + specific + unspecific');
    out.generalization.model_02_fixed    = fitlm(t,'FPSA_G ~ 1 + specific + unspecific');
    % FPSA_model_adversitytuning
    out.baseline.model_03_fixed          = fitlm(t,'FPSA_B ~ 1 + specific + unspecific + Gaussian');
    out.generalization.model_03_fixed    = fitlm(t,'FPSA_G ~ 1 + specific + unspecific + Gaussian');
    varargout{1}   = out;

elseif strcmp(varargin{1},'FPSA_model_singlesubject');%% Models single-subject FPSA matrices.
    %% same as FPSA_model, but on gathers a model parameter for single subjects.
    % Input a table if you like to model a custom FPSA matrix.
    if ~istable(varargin{2})
        fprintf('VARARGIN interpreted as SELECTOR cell.\n')
        selector   = varargin{2};
        t          = FPSA_FearGen('runs',runs,'FPSA_get_table',selector);
    else fprintf('VARARGIN interpreted as a TABLE.\n')
        t       = varargin{2};
    end
    %% test the model for B, T
    Model.model_01.w1 = nan(length(unique(t.subject)'),2);
    Model.model_02.w1 = nan(length(unique(t.subject)'),2);
    Model.model_02.w2 = nan(length(unique(t.subject)'),2);
    Model.model_03.w1 = nan(length(unique(t.subject)'),2);
    Model.model_03.w2 = nan(length(unique(t.subject)'),2);
    Model.model_03.w3 = nan(length(unique(t.subject)'),2);
    M                 = nan(length(unique(t.subject)'),2,3,3);%[subjects,phase,model,param]
    
    for ns = unique(t.subject)'
        t2                = t(ismember(t.subject,categorical(ns)),:);
        if ~isnan(sum([t2.FPSA_B;t2.FPSA_G]))% valid or not: Criteria for validity: Both the B and G FPSA matrices must not contain any NaNs.
            cprintf([0 1 0],'Fitting an circular and flexibile LM to subject %03d...\n',double(ns));
            B                 = fitlm(t2,'FPSA_B ~ 1 + circle');
            T                 = fitlm(t2,'FPSA_G ~ 1 + circle');
            
            Model.model_01.w1(ns,:) = [B.Coefficients.Estimate(2) T.Coefficients.Estimate(2)];
            M(ns,1,1,1)             = B.Coefficients.Estimate(2);
            M(ns,2,1,1)             = T.Coefficients.Estimate(2);
            MC(ns,1,1)              = B.ModelCriterion;
            MC(ns,2,1)              = T.ModelCriterion;
            LL(ns,1,1)              = B.LogLikelihood;
            LL(ns,2,1)              = T.LogLikelihood;
            
            
            %
            B                       = fitlm(t2,'FPSA_B ~ 1 + specific + unspecific');
            T                       = fitlm(t2,'FPSA_G ~ 1 + specific + unspecific');
            Model.model_02.w1(ns,:) = [B.Coefficients.Estimate(2) T.Coefficients.Estimate(2)];
            Model.model_02.w2(ns,:) = [B.Coefficients.Estimate(3) T.Coefficients.Estimate(3)];
            M(ns,1,2,1)             = B.Coefficients.Estimate(2);
            M(ns,2,2,1)             = T.Coefficients.Estimate(2);
            M(ns,1,2,2)             = B.Coefficients.Estimate(3);
            M(ns,2,2,2)             = T.Coefficients.Estimate(3);
            MC(ns,1,2)              = B.ModelCriterion;
            MC(ns,2,2)              = T.ModelCriterion;
            LL(ns,1,2)              = B.LogLikelihood;
            LL(ns,2,2)              = T.LogLikelihood;
            %
            B                       = fitlm(t2,'FPSA_B ~ 1 + specific + unspecific + Gaussian');
            T                       = fitlm(t2,'FPSA_G ~ 1 + specific + unspecific + Gaussian');
            Model.model_03.w1(ns,:) = [B.Coefficients.Estimate(2) T.Coefficients.Estimate(2)];
            Model.model_03.w2(ns,:) = [B.Coefficients.Estimate(3) T.Coefficients.Estimate(3)];
            Model.model_03.w3(ns,:) = [B.Coefficients.Estimate(4) T.Coefficients.Estimate(4)];
            M(ns,1,3,1)             = B.Coefficients.Estimate(2);
            M(ns,2,3,1)             = T.Coefficients.Estimate(2);
            M(ns,1,3,2)             = B.Coefficients.Estimate(3);
            M(ns,2,3,2)             = T.Coefficients.Estimate(3);
            M(ns,1,3,3)             = B.Coefficients.Estimate(4);
            M(ns,2,3,3)             = T.Coefficients.Estimate(4);
            MC(ns,1,3)              = B.ModelCriterion;
            MC(ns,2,3)              = T.ModelCriterion;
            LL(ns,1,3)              = B.LogLikelihood;
            LL(ns,2,3)              = T.LogLikelihood;
        else
            cprintf([1 0 0],'FPSA matrix contains NaN, will not be modelled...\n');
        end
    end
    varargout{1} = Model;
    varargout{2} = M;
    varargout{3} = MC;
    varargout{4} = LL;


elseif strcmp(varargin{1},'model2text'); %% spits text from a model object
    %% handy function to dump model output to a text file that let you easily
    %paste it to the manuscript ;-\
    
    model = varargin{2};
    a     = evalc('disp(model)');
    fid   = fopen(sprintf('%s/data/midlevel/%s.txt',path_project,model.Formula),'w');
    fwrite(fid,a);
    fclose(fid);
elseif strcmp(varargin{1},'prevalence')
    %% prevalence
    C          = FPSA_FearGen('FPSA_model_singlesubject',{'fix',1:100});
    beta1_base         = C.model_02.w1(:,1);
    beta2_base         = C.model_02.w2(:,1);
    beta1_test         = C.model_02.w1(:,2);
    beta2_test         = C.model_02.w2(:,2);
    beta1_diff         = C.model_02.w1(:,2)-C.model_02.w1(:,1);
    beta2_diff         = C.model_02.w2(:,2)-C.model_02.w2(:,1);
    beta_diff_test     = beta1_test - beta2_test;
    beta_diffdiff      = (beta1_test - beta2_test) - (beta1_base - beta2_base);%how much does w1 increase more than w2 does? (Interaction)
    
    subs1 = FPSA_FearGen('current_subject_pool',1,'get_subjects');
    subs0 = FPSA_FearGen('current_subject_pool',0,'get_subjects');
    % all subs
    sum(beta_diffdiff>0)
    sum(beta_diffdiff>0)./length(subs0)
    
    binopdf(sum(beta_diffdiff>0),length(subs0),.5) %.5 for chance level.
    
    % learners only
    ind = ismember(subs0,subs1);
    sum(beta_diffdiff(ind)>0)
    sum(beta_diffdiff(ind)>0)./length(subs1)
    binopdf(sum(beta_diffdiff(ind)>0),length(subs1),.5) %.5 for chance level.
    
    %
   
    w_spec_test = beta1_test;
    w_unspec_test = beta2_test;
    w_spec_baseline = beta1_base;
    w_unspec_baseline = beta2_base;
    
    
    anis_TvB = (w_spec_test-w_unspec_test) - (w_spec_baseline-w_unspec_baseline);
    sum(anis_TvB>0) 
    fprintf('N = %d subjects out of %d show bigger aniso in Test than in Baseline.\n',sum(anis_TvB>0),length(subs0))
    
elseif strcmp(varargin{1},'figure_03C');
    %% plots the main model comparison figure;
    selector  = varargin{2};
    C         = FPSA_FearGen('FPSA_model_singlesubject',selector);
    %%
    % circular model
    M         = mean(C.model_01.w1);
    SEM       = std(C.model_01.w1)./sqrt(length(C.model_01.w1));
    %flexible model
    Mc        = mean(C.model_02.w1);
    SEMc      = std(C.model_02.w1)./sqrt(length(C.model_01.w1));
    Ms        = mean(C.model_02.w2);
    SEMs      = std(C.model_02.w2)./sqrt(length(C.model_01.w1));
    %gaussian model
    Mcg       = mean(C.model_03.w1);
    SEMcg     = std(C.model_03.w1)./sqrt(length(C.model_01.w1));
    Msg       = mean(C.model_03.w2);
    SEMsg     = std(C.model_03.w2)./sqrt(length(C.model_01.w1));
    Mg        = mean(C.model_03.w3);
    SEMg      = std(C.model_03.w3)./sqrt(length(C.model_01.w1));
    
    
    %% get the p-values
    [H   P]     = ttest(C.model_01.w1(:,1)-C.model_01.w1(:,2));%compares baseline vs test the circular model parameters
    
    [Hc Pc]     = ttest(C.model_02.w1(:,1)-C.model_02.w1(:,2));%compares spec before to after
    [Hs Ps]     = ttest(C.model_02.w2(:,1)-C.model_02.w2(:,2));%compares unspec before to after
    [Hcs Pcs]   = ttest(C.model_02.w1(:,2)-C.model_02.w2(:,2));%compares spec > unspec after
    % same as before
    [Hgc Pgc]   = ttest(C.model_03.w1(:,1)-C.model_03.w1(:,2));%compares cosine before to after
    [Hgcs Pgcs] = ttest(C.model_03.w1(:,2)-C.model_03.w2(:,2));%compares cosine after to sine after
    [Hgg Pgg]   = ttest(C.model_03.w3(:,1)-C.model_03.w3(:,2));%compares sine before to after
    %     %%anova on interaction of Time x Parameter
    %     y = [C.model_02.w1;C.model_02.w2];
    %     reps = length(C.model_02.w1);
    %     p = anova2(y,reps);
    %     %matlab can't deal with the repeated measures ANOVA, using Jasp instead
    
    spec   = C.model_02.w1(:,2)-C.model_02.w1(:,1);
    unspec = C.model_02.w2(:,2)-C.model_02.w2(:,1);
    [hIA,pIA,ciIA,statsIA] = ttest(spec,unspec);
    %%
    %%
    figure;
    if ispc
        set(gcf,'position',[-200+500        1200        898         604]);
    else
        set(gcf,'position',[2150         335         898         604]);
    end
    %
    X    = [1 2 4 5 6 7  9 10 11 12 13 14]/1.5;
    Y    = [M Mc Ms Mcg Msg Mg];
    Y2   = [SEM SEMc SEMs SEMcg SEMsg SEMg];
    ylims = [floor(min(Y-Y2)*100)./100 ceil(max(Y+Y2)*100)./100+.07];
    bw   = .5;
    hold off;
    for n = 1:size(Y,2)
        h       = bar(X(n),Y(n));
        legh(n) = h;
        hold on
        try %capsize is 2016b compatible.
            errorbar(X(n),Y(n),Y2(n),'k.','marker','none','linewidth',1.5,'capsize',10);
        catch
            errorbar(X(n),Y(n),Y2(n),'k.','marker','none','linewidth',1.5);
        end
        if ismember(n,[1 3 5 7 9 11])
            try %2016b compatibility.
                set(h,'FaceAlpha',.1,'FaceColor','w','EdgeAlpha',1,'EdgeColor',[0 0 0],'LineWidth',1.5,'BarWidth',bw,'LineStyle','-');
            catch
                set(h,'FaceColor','w','EdgeColor',[0 0 0],'LineWidth',1.5,'BarWidth',bw,'LineStyle','-');
            end
        else
            try
                set(h,'FaceAlpha',.5,'FaceColor',[0 0 0],'EdgeAlpha',0,'EdgeColor',[.4 .4 .4],'LineWidth',1,'BarWidth',bw,'LineStyle','-');
            catch
                set(h,'FaceColor',[0 0 0],'EdgeColor',[.4 .4 .4],'LineWidth',1,'BarWidth',bw,'LineStyle','-');
            end
        end
    end
    %
    box off;
    L          = legend(legh(1:2),{'Baseline' 'Generaliz.'},'box','off');
    try
        L.Position = L.Position + [0.1/2 0 0 0];
        L.FontSize = 12;
    end
    set(gca,'linewidth',1.8);
    % xticks
    xtick = [mean(X(1:2)) mean(X(3:4)) mean(X(5:6)) mean(X(7:8)) mean(X(9:10)) mean(X(11:12)+.1) ];
    label = {'\itw_{\rmcircle}' '\itw_{\rmspec.}' '\itw_{\rmunspec.}' '\itw_{\rmspec.}' '\itw_{\rmunspec.}' '\itw_{\rmGaus.}' };
    for nt = 1:length(xtick)
        h = text(xtick(nt),-.02,label{nt},'horizontalalignment','center','fontsize',20,'rotation',45,'fontangle','italic','fontname','times new roman');
    end
    try
        set(gca,'xtick',[3 8]./1.5,'xcolor','none','color','none','XGrid','on','fontsize',16);
    catch
        set(gca,'xtick',[3 8]./1.5,'color','none','XGrid','on','fontsize',16);
    end
    %
    text(-.5,ylims(2),'\beta','fontsize',28,'fontweight','bold');
    
    
    ylim(ylims);
    set(gca,'ytick', 0:.05:.2,'yticklabels', {'0' '.05' '.1' '.15' '.2'})
    axis normal
    % asteriks
    ast_line = repmat(max(Y+Y2)+.002,1,2);
    hold on
    ylim(ylims);
    h= line([X(1)-bw/2 X(2)+bw/2],ast_line);set(h,'color','k','linewidth',1); %B vs T model 01
    h= line([X(3)-bw/2 X(4)+bw/2],ast_line);set(h,'color','k','linewidth',1); % B vs T, spec comp model 02
    h= line([mean(X(3:4)) mean(X(5:6))],ast_line+.015);set(h,'color','k','linewidth',1); %delta spec vs delta unspec model_2 testphase
    h= line(repmat(mean(X(3:4)),1,2),ast_line + [.01 .015]);set(h,'color','k','linewidth',1); %vertical miniline to show delta
    h = line(repmat(mean(X(5:6)),1,2),ast_line + [.00 .015]);set(h,'color','k','linewidth',1);  %vertical miniline to show delta
    h= line([X(5)-bw/2 X(6)+bw/2],ast_line);set(h,'color','k','linewidth',1); % B vs T, unspec comp model 02 (serves the delta spec vs delta unspec thing)
    
    h= line([X(7)-bw/2 X(8)+bw/2],ast_line);set(h,'color','k','linewidth',1); %B vs T spec model_03
    %     h= line([X(8)-bw/2 X(10)+bw/2],repmat(max(ylim),1,2)-.0025);set(h,'color','k','linewidth',1);
    %     h= line([X(11)-bw/2 X(12)+bw/2],repmat(max(ylim),1,2)-.1);set(h,'color','k','linewidth',1);
    %
    text(mean(X(1:2))  ,ast_line(1)+.0025, pval2asterix(P),'HorizontalAlignment','center','fontsize',16);
    text(mean(X(3:4))  ,ast_line(1)+.0025, pval2asterix(Pc),'HorizontalAlignment','center','fontsize',16);
    
    text(mean(X(4:5))  ,ast_line(1)+.015+.0025, pval2asterix(pIA),'HorizontalAlignment','center','fontsize',16); %diff B vs T spec vs unspec model_02
    %     text(mean(X([4 6])),ast_line(1)+.0055, pval2asterix(Pcs),'HorizontalAlignment','center','fontsize',16);
    %     text(mean(X([4 6])),ast_line(1)+.015 , sprintf('p = %05.3f',Pcs),'HorizontalAlignment','center','fontsize',13);
    text(mean(X([7 8])),ast_line(1)+.0025, pval2asterix(Pgc),'HorizontalAlignment','center','fontsize',16);
    %     text(mean(X([8 10])),max(ylim)      , pval2asterix(Pgcs),'HorizontalAlignment','center','fontsize',16);
    %     text(mean(X([11 12])),max(ylim)-.09      , pval2asterix(Pgg),'HorizontalAlignment','center','fontsize',12);
    % model names
    ylim(ylims)
    %     h = line([X(1)-bw/2 X(2)+bw/2],[-.022 -.022],'linestyle','--');
    %     set(h(1),'color','k','linewidth',1,'clipping','off');
    text(mean(X(1:2)),ast_line(1)+.03,sprintf('Bottom-up\nSaliency\nmodel'),'Rotation',0,'HorizontalAlignment','center','FontWeight','normal','fontname','Helvetica','fontsize',14,'verticalalignment','bottom');
    %     h = line([X(3)-bw/2 X(6)+bw/2],[-.022 -.022],'linestyle','--');
    %     set(h(1),'color','k','linewidth',1,'clipping','off');
    text(mean(X(3:6)),ast_line(1)+.03,sprintf('Adversity\nCategorization\nmodel'),'Rotation',0,'HorizontalAlignment','center','FontWeight','normal','fontname','Helvetica','fontsize',14,'verticalalignment','bottom');
    
    %     h = line([X(7)-bw/2 X(end)+bw/2],[-.022 -.022],'linestyle','--');
    %     set(h(1),'color','k','linewidth',1,'clipping','off');
    text(mean(X(7:end)),ast_line(1)+.03,sprintf('Adversity\nTuning\nmodel'),'Rotation',0,'HorizontalAlignment','center','FontWeight','normal','fontname','Helvetica','fontsize',14,'verticalalignment','bottom');
    %%
    set(gcf,'Color',[1 1 1]);
    % SaveFigure(sprintf('%s/data/midlevel/figures/figure_03C.png',path_project),'-transparent','-r300');
    
    %
    %     keyboard
elseif strcmp(varargin{1},'figure_04B') %SVM barplot
    % to run this, you need a csv that contains the accuracies for classification along specific (CS+/CS-) and unspecific (-90/90) dimensions
    filename = sprintf('%s/data/midlevel/accuracy_SVM_py_csv.csv',path_project);
    a=csvread(filename,1,0);
    spec = a(:,3)==0;
    unspec = a(:,3)==90;
    base = a(:,2)==2;
    test = a(:,2)==4;
    acc_base_spec = a(spec&base,end);
    acc_base_unspec = a(unspec&base,end);
    acc_test_spec = a(spec&test,end);
    acc_test_unspec = a(unspec&test,end);
    
    M = mean([acc_base_spec acc_test_spec acc_base_unspec  acc_test_unspec]);
    SEM = std([acc_base_spec acc_test_spec acc_base_unspec  acc_test_unspec])./sqrt(74);
    
    figure;
    b=bar(M);set(b,'FaceColor','none');
    hold on;
    errorbar(M,SEM,'k.','LineWidth',2);
    box off
    ylim([.4 .6])
    legend('Baseline','Test');
    set(gca,'YTick',.3:.1:.6,'LineWidth',1.5,'FontSize',16)
    % SaveFigure(sprintf('%s/data/midlevel/figures/figure_04B.png',path_project),'-transparent','-r300');
    
elseif strcmp(varargin{1},'figure_04D') % differences between stimuli.
    
    fix = Fixmat(6,2);
    for cs = 1:8
        dummy   = imread(strrep(fix.find_stim,'ave',sprintf('%02d',ID)));
        dummy  = dummy( fix.rect(1):fix.rect(1)+fix.rect(3)-1,  fix.rect(2):fix.rect(2)+fix.rect(4)-1);
        allstims(:,:,cs) = dummy;
    end
    for cs = 1:4
        diffimg(:,:,cs) = allstims(:,:,cs)-allstims(:,:,cs+4);
        
        stimdiff        = repmat(adapthisteq(rgb2gray(diffimg(:,:,:,cs))),[1 1 3]);
        %  imwrite(strrep(fix.find_stim,'ave',sprintf('test%02dto%02d_neg_adjhisteq',cs,cs+4)));
    end
    
    dummy   = imread(strrep(fix.find_stim,'ave',sprintf('%02d',ID)));
    stimdiff    = imread(strrep(fix.find_stim,'ave',sprintf('diff%02dto%02d_neg_adjhisteq',cs,cs+4)));
    stimdiff    = repmat(adapthisteq(rgb2gray(stimdiff)),[1 1 3]);
    %         imwrite(bild,strrep(fix.find_stim,'ave',sprintf('test%02dto%02d_neg_adjhisteq',cs,cs+4)));
    
    
    % SaveFigure(sprintf('%s/data/midlevel/figures/figure_04B.png',path_project),'-transparent','-r300');
    
    %  %% does individual hyperplane correlate with difference map?
    % g = Group(FPSA_FearGen('get_subjects'));
    % csps = g.getcsp;
    % fix = Fixmat(6,2);
    %
    % for ID = 1:8
    %     dummy   = imread(strrep(fix.find_stim,'ave',sprintf('%02d',ID)));
    %     dummy  = dummy( fix.rect(1):fix.rect(1)+fix.rect(3)-1,  fix.rect(2):fix.rect(2)+fix.rect(4)-1);
    %     bild(:,:,ID) = dummy;
    %     bildRGB(:,:,:,ID)    = repmat(dummy,[1 1 3]);
    % end
    %
    % for cs = 1:4
    %     diffbild(:,:,cs) = bild(:,:,cs)-bild(:,:,cs+4);
    % end
    %
    % diffbild_r   = imresize(diffbild,.1);
    % diffbild_vec = double(reshape(diffbild_r,2500,4));
    % diffbild_vec = repmat(diffbild_vec,1,2); % so we can loop through csps and 1 is 5, 2 is 6 etc..
    %
    % HP_basetest = subs_HP(:,:,:,[1 5]);
    % HP_vec = reshape(HP_basetest,2500,74,2);
    %
    % for ph = 1:2
    %     for ns = 1:74
    %         [rho(ns,ph)] = corr(HP_vec(:,ns,ph),diffbild_vec(:,csps(ns)));
    %     end
    % end
    % %across everyone?
    % for ph = 1:2
    %     for face = 1:4
    %         subs_id = csps==face;
    %         HP_all_ph = HP_vec(:,subs_id,ph);
    %         nsubs = sum(subs_id);
    %         [rho_all(face,ph) p_all(face,ph)] = corr(HP_all_ph(:),repmat(diffbild_vec(:,face),nsubs,1));
    %     end
    % end
    % % does that change?
    % figure;
    % for ph = 1:2
    %     rhoz(:,ph) = fisherz(rho(:,ph));
    % end
    % bar(fisherz_inverse(mean(rhoz)));
    % hold on;
    % errorbar(fisherz_inverse(mean(rhoz)),fisherz_inverse(std(rhoz))./sqrt(length(rho)));
    
    
elseif strcmp(varargin{1},'figure_05A') %4D before
    
    %% now plots band of timewindowed model params
    window_size    = varargin{2};
    window_overlap = varargin{3};
    [sim,model,timebins] = FPSA_FearGen('get_fpsa_timewindowed',window_size,window_overlap);
    %model.w[subjects,phase,model,param,time]
    modelnum = 2;
    figure;
    if ispc
        set(gcf,'position',[-200+500        1200        898         504]);
    else
        set(gcf,'position',[2150         335         898         504]);
    end
    colors = {'r','b'};
    titles = {'Base','Generalization'};
    for run = 1:2
        subplot(1,2,run)
        for param = 1:2
            params = squeeze(model.w(:,run,modelnum,param,:));
            M = nanmean(params);
            SEM = nanSEM(params);
            plot(M,colors{param},'LineWidth',2)
            hold on
            x = 1:size(params,2);
            h=fill([x fliplr(x)],[M+SEM fliplr(M-SEM)],colors{param});
            h.EdgeColor = colors{param};
            h.FaceAlpha = .5;
        end
        xlim([0 max(x)+1]);
        
        box off
        axis square
        title(titles{run},'FontSize',14);
        set(gca,'FontSize',12)
        if run ==1
            ylabel('beta [a.u.]')
        end
        xlabel('mean timewindow [ms]')
        set(gca,'XTick',1:4:length(x),'XTickLabels',floor(mean(timebins(1:4:end,:),2)),'XTickLabelRotation',45,'fontsize',16)
    end
    EqualizeSubPlotYlim(gcf)
    varargout{1} = sim;
    varargout{2} = model;
    
    %SaveFigure(sprintf('%s/data/midlevel/figures/figure_05A.png',path_project),'-transparent','-r300');
    
    keyboard
    
elseif strcmp(varargin{1},'get_scr_singletrials'); %% get singletrial rawdata for fpsa on SCR
    %%
    subs = FPSA_FearGen('get_subjects');
    scrsubs  = subs(ismember(subs,Project.subjects(Project.subjects_scr)));
    out_raw = nan(78,27,length(scrsubs));
    
    path2data = sprintf('%sdata/midlevel/scr_singletrials_N%2d.mat',path_project,length(scrsubs));
    if  ~exist(path2data)||force == 1
        sc= 0;
        for sub = scrsubs(:)'
            sc= sc+1;
            [~,raw] = Subject(sub).scr.ledalab_summary;
            out_raw(:,:,sc) = raw;
        end
        save(path2data,'out_raw')
    else
        load(path2data)
    end
    varargout{1} = out_raw;
    
elseif strcmp(varargin{1},'get_fpsa_scr'); %%  FPSA on SCR data, just analog to fixations, also considers 3 runs in testphase seperately, just like FPSA 'fair'
    %%
    subs = FPSA_FearGen('get_subjects');
    scrsubs  = subs(ismember(subs,Project.subjects(Project.subjects_scr)));
    out_raw = FPSA_FearGen('get_scr_singletrials');
    
    phsel = [1 11;12 22; 23 33];
    runs = 1:3;
    filename     = sprintf('%s/data/midlevel/fpsa_fair_SCR_subjectpool_N%02d_runs_%s_sim_%s.mat',path_project,length(scrsubs),mat2str(runs),method);
    if ~exist(filename)||force ==1
        runc = 0;
        for run = runs(:)'
            runc = runc+1;
            for sc = 1:numel(scrsubs);
                data = cat(2,out_raw(1:11,1:8,sc),out_raw(phsel(run,1):phsel(run,2),19:26,sc)); %11trials x 2x8 conds (2 phases, 8 conds)
                if sc == 38 && run == 1 %there is a NaN there...
                    sim.(method)(sc,:,runc) = 1-corr(data,'rows','pairwise');
                else
                    sim.(method)(sc,:,runc) = pdist(data',method);
                end
            end
        end
        sim.(method) = mean(sim.(method),3);
        save(filename,'sim');
    else
        load(filename);
    end
    varargout{1} = sim;
elseif strcmp(varargin{1},'get_fpsa_rate'); %%  FPSA on SCR data, just analog to fixations, also considers 3 runs in testphase seperately, just like FPSA 'fair'
    
    subs = FPSA_FearGen('get_subjects');
    method = 'euclidean';
    filename     = sprintf('%s/data/midlevel/fpsa_Rate_subjectpool_N%02d_sim_%s.mat',path_project,length(subs),method);
    if ~exist(filename)||force ==1
        clear sim
        for sc = 1:numel(subs)
            s = Subject(subs(sc));
            
            cc= 0;
            for ph = [2 4]
                clear rating
                rating = s.get_rating(ph);
                for c = unique(rating.x)
                    cc = cc+1;
                    M(cc) = nanmean(rating.y(rating.x==c));
                end
            end
            sim.(method)(sc,:) = pdist(M',method);
        end
        save(filename,'sim');
    else
        load(filename);
    end
    varargout{1} = sim;
    
elseif strcmp(varargin{1},'fpsa_plot_scrrate')
    modality = varargin{2};
    if strcmp(modality,'scr')
        sim = FPSA_FearGen('get_fpsa_scr');
    elseif strcmp(modality,'rate')
        sim = FPSA_FearGen('get_fpsa_rate');
        sim.correlation = sim.euclidean; %only to be able to use existing code.
    else
        fprintf('enter valid modality as second input (''scr'' or ''rate'')')
    end
    f=figure;
    set(f,'Position',[548 828 995 949]);
    %% get similarity matrix
    cormatz = squareform(nanmean(sim.correlation));
    %% plot similarity matrices
    [d u]   = GetColorMapLimits(cormatz,.9);
    labels  = {sprintf('-135%c',char(176)) sprintf('-90%c',char(176)) sprintf('-45%c',char(176)) 'CS+' sprintf('+45%c',char(176)) sprintf('+90%c',char(176)) sprintf('+135%c',char(176)) 'CS-' };
    labels  = {'' sprintf('-90%c',char(176)) '' 'CS+' '' sprintf('+90%c',char(176)) '' 'CS-' };
    fs      = 12;
    H(1) = subplot(3,3,1);
    h = imagesc(cormatz(1:8,1:8),[d u]);
    axis square;axis off;
    h = text(0,4,'CS+');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(0,8,'CS-');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(4,9,'CS+');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(8,9,'CS-');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold')   ;
    title('Baseline','fontweight','normal','fontsize',fs*3/2,'FontWeight','bold');
    H(2) = subplot(3,3,2);
    h=imagesc(cormatz(9:16,9:16),[d u]);
    axis square;axis off;
    h = text(4,9,'CS+');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(8,9,'CS-');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    title('Generalization','fontweight','normal','fontsize',fs*3/2,'FontWeight','bold');
    %% plot MDS
    subplot(3,3,3)
    FPSA_FearGen('get_mdscale',cormatz,2);
    axis square
    set(gca,'XTick',[],'YTick',[])
    ll = findobj(gca,'Type','Line');
    set(ll,'MarkerSize',50,'LineWidth',2)
    tt = findobj(gca,'Type','Text');
    set(tt,'FontSize',13);
    title('MDS','fontweight','normal','fontsize',fs*3/2,'FontWeight','bold');
    
    %%%%%%%%
    %%%%%%%%
    %% prepare table for fitting FPSA
    clear B
    clear T
    clear BB
    clear TT
    B         = FPSA_FearGen('get_block',sim,1,1);
    T         = FPSA_FearGen('get_block',sim,2,2);
    for n = 1:size(sim.correlation,1)
        BB(n,:) = squareform(B(:,:,n));
        TT(n,:) = squareform(T(:,:,n));
    end
    BB       = BB';
    TT       = TT';
    % some indicator variables for phase, subject identities.
    phase    = repmat([repmat(1,size(BB,1)/2,1); repmat(2,size(BB,1)/2,1)],1,size(BB,2));
    subject  = repmat(1:size(sim.correlation,1),size(BB,1),1);
    S        = subject(:);
    P        = phase(:);
    %% our models:
    %MODEL1: perfectly circular similarity model;
    %MODEL2: flexible circular similarity model;
    %MODEL3: Model2 + a Gaussian.
    % a circular FPSA matrix for B and T replicated by the number of subjects
    x          = [pi/4:pi/4:2*pi];
    w          = [cos(x);sin(x)];
    model1     = repmat(repmat(squareform_force(w'*w),1,1),1,size(subject,2));%we use squareform_force as the w'*w is not perfectly positive definite matrix due to rounding errors.
    %
    model2_c   = repmat(repmat(squareform_force(cos(x)'*cos(x)),1,1),1,size(subject,2));%
    model2_s   = repmat(repmat(squareform_force(sin(x)'*sin(x)),1,1),1,size(subject,2));%
    %
    %getcorrmat(amp_circ, amp_gau, amp_const, amp_diag, varargin)
    [cmat]     = getcorrmat(0,3,1,1);%see model_rsa_testgaussian_optimizer
    model3_g   = repmat(repmat(squareform_force(cmat),1,1),1,size(subject,2));%
    %% add all this to a TABLE object.
    t          = table(1-BB(:),1-TT(:),model1(:),model2_c(:),model2_s(:),model3_g(:),categorical(subject(:)),categorical(phase(:)),'variablenames',{'FPSA_B' 'FPSA_G' 'circle' 'specific' 'unspecific' 'Gaussian' 'subject' 'phase'});
    %% get FPSA model from this table
    C =  FPSA_FearGen('FPSA_model_singlesubject',t);
    
    %% plots the main model comparison figure;
    %%
    Nmodelled = sum(~isnan(C.model_01.w1(:,1)));
    % circular model
    M         = nanmean(C.model_01.w1);
    SEM       = nanstd(C.model_01.w1)./sqrt(Nmodelled);
    %flexible model
    Mc        = nanmean(C.model_02.w1);
    SEMc      = nanstd(C.model_02.w1)./sqrt(Nmodelled);
    Ms        = nanmean(C.model_02.w2);
    SEMs      = nanstd(C.model_02.w2)./sqrt(Nmodelled);
    %gaussian model
    Mcg       = nanmean(C.model_03.w1);
    SEMcg     = nanstd(C.model_03.w1)./sqrt(Nmodelled);
    Msg       = nanmean(C.model_03.w2);
    SEMsg     = nanstd(C.model_03.w2)./sqrt(Nmodelled);
    Mg        = nanmean(C.model_03.w3);
    SEMg      = nanstd(C.model_03.w3)./sqrt(Nmodelled);
    
    %% get the p-values
    [H   P]     = ttest(C.model_01.w1(:,1)-C.model_01.w1(:,2));%compares baseline vs test the circular model parameters
    
    [Hc Pc]     = ttest(C.model_02.w1(:,1)-C.model_02.w1(:,2));%compares cosine before to after
    [Hs Ps]     = ttest(C.model_02.w2(:,1)-C.model_02.w2(:,2));%compares sine before to after
    [Hcs Pcs]   = ttest(C.model_02.w1(:,2)-C.model_02.w2(:,2));%compares cosine after to sine after
    % same as before
    [Hgc Pgc]   = ttest(C.model_03.w1(:,1)-C.model_03.w1(:,2));%compares cosine before to after
    [Hgcs Pgcs] = ttest(C.model_03.w1(:,2)-C.model_03.w2(:,2));%compares cosine after to sine after
    [Hgg Pgg]   = ttest(C.model_03.w3(:,1)-C.model_03.w3(:,2));%compares sine before to after
    %     %%anova on interaction of Time x Parameter
    %     y = [C.model_02.w1;C.model_02.w2];
    %     reps = length(C.model_02.w1);
    %     p = anova2(y,reps);
    %     %matlab can't deal with the repeated measures ANOVA, using Jasp instead
    
    spec   = C.model_02.w1(:,2)-C.model_02.w1(:,1);
    unspec = C.model_02.w2(:,2)-C.model_02.w2(:,1);
    [hIA,pIA,ciIA,statsIA] = ttest(spec,unspec);
    
    %
    subplot(3,3,4:9)
    X    = [1 2 4 5 6 7  9 10 11 12 13 14]/1.5;
    Y    = [M Mc Ms Mcg Msg Mg];
    Y2   = [SEM SEMc SEMs SEMcg SEMsg SEMg];
    ylims = [floor(min(Y-Y2)*100)./100 ceil(max(Y+Y2)*100)./100+.07];
    bw   = .5;
    hold off;
    for n = 1:size(Y,2)
        h       = bar(X(n),Y(n));
        legh(n) = h;
        hold on
        try %capsize is 2016b compatible.
            errorbar(X(n),Y(n),Y2(n),'k.','marker','none','linewidth',1.5,'capsize',10);
        catch
            errorbar(X(n),Y(n),Y2(n),'k.','marker','none','linewidth',1.5);
        end
        if ismember(n,[1 3 5 7 9 11])
            try %2016b compatibility.
                set(h,'FaceAlpha',.1,'FaceColor','w','EdgeAlpha',1,'EdgeColor',[0 0 0],'LineWidth',1.5,'BarWidth',bw,'LineStyle','-');
            catch
                set(h,'FaceColor','w','EdgeColor',[0 0 0],'LineWidth',1.5,'BarWidth',bw,'LineStyle','-');
            end
        else
            try
                set(h,'FaceAlpha',.5,'FaceColor',[0 0 0],'EdgeAlpha',0,'EdgeColor',[.4 .4 .4],'LineWidth',1,'BarWidth',bw,'LineStyle','-');
            catch
                set(h,'FaceColor',[0 0 0],'EdgeColor',[.4 .4 .4],'LineWidth',1,'BarWidth',bw,'LineStyle','-');
            end
        end
    end
    %
    box off;
    L          = legend(legh(1:2),{'Baseline' 'Generaliz.'},'box','off');
    try
        L.Position = L.Position + [0.1/2 0 0 0];
        L.FontSize = 12;
    end
    set(gca,'linewidth',1.8);
    % xticks
    xtick = [mean(X(1:2)) mean(X(3:4)) mean(X(5:6)) mean(X(7:8)) mean(X(9:10)) mean(X(11:12)+.1) ];
    label = {'\itw_{\rmcircle}' '\itw_{\rmspec.}' '\itw_{\rmunspec.}' '\itw_{\rmspec.}' '\itw_{\rmunspec.}' '\itw_{\rmGaus.}' };
    for nt = 1:length(xtick)
        h = text(xtick(nt),-.02,label{nt},'horizontalalignment','center','fontsize',20,'rotation',45,'fontangle','italic','fontname','times new roman');
    end
    try
        set(gca,'xtick',[3 8]./1.5,'xcolor','none','color','none','XGrid','on','fontsize',16);
    catch
        set(gca,'xtick',[3 8]./1.5,'color','none','XGrid','on','fontsize',16);
    end
    %
    text(-.5,ylims(2),'\beta','fontsize',28,'fontweight','bold');
    
    
    ylim(ylims);
    if strcmp(modality,'scr')
        set(gca,'ytick', 0:.05:.2,'yticklabels', {'0' '.05' '.1' '.15' '.2'})
    else
        ylims(2) = -ylims(1);
        ylim(ylims)
    end
    
    axis normal
    % asteriks
    ast_line = repmat(max(Y+Y2)+.002,1,2);
    hold on
    ylim(ylims);
    h= line([X(1)-bw/2 X(2)+bw/2],ast_line);set(h,'color','k','linewidth',1); %B vs T model 01
    h= line([X(3)-bw/2 X(4)+bw/2],ast_line);set(h,'color','k','linewidth',1); % B vs T, spec comp model 02
    h= line([mean(X(3:4)) mean(X(5:6))],ast_line+.015);set(h,'color','k','linewidth',1); %delta spec vs delta unspec model_2 testphase
    h= line([X(5)-bw/2 X(6)+bw/2],ast_line);set(h,'color','k','linewidth',1); % B vs T, unspec comp model 02 (serves the delta spec vs delta unspec thing)
    
    h= line([X(7)-bw/2 X(8)+bw/2],ast_line);set(h,'color','k','linewidth',1); %B vs T spec model_03
    h= line([X(9)-bw/2 X(10)+bw/2],ast_line);set(h,'color','k','linewidth',1);
    h= line([X(11)-bw/2 X(12)+bw/2],ast_line);set(h,'color','k','linewidth',1);
    
    text(mean(X(1:2))  ,ast_line(1)+.0025, pval2asterix(P),'HorizontalAlignment','center','fontsize',12);
    text(mean(X(3:4))  ,ast_line(1)+.0025, pval2asterix(Pc),'HorizontalAlignment','center','fontsize',12);
    text(mean(X(4:5))  ,ast_line(1)+.015+.0025, pval2asterix(pIA),'HorizontalAlignment','center','fontsize',12); %diff B vs T spec vs unspec model_02
    
    text(mean(X(5:6))  ,ast_line(1)+.0025, pval2asterix(Ps),'HorizontalAlignment','center','fontsize',12);
    text(mean(X([7 8])),ast_line(1)+.0025, pval2asterix(Pgc),'HorizontalAlignment','center','fontsize',12);
    text(mean(X([9 10])),ast_line(1)+.0025     , pval2asterix(Pgcs),'HorizontalAlignment','center','fontsize',12);
    text(mean(X([11 12])),ast_line(1)+.0025      , pval2asterix(Pgg),'HorizontalAlignment','center','fontsize',12);
    %     model names
    ylim(ylims)
    set(h(1),'color','k','linewidth',1,'clipping','off');
    text(mean(X(1:2)),ast_line(1)+.03,sprintf('Bottom-up\nSaliency\nmodel'),'Rotation',0,'HorizontalAlignment','center','FontWeight','normal','fontname','Helvetica','fontsize',14,'verticalalignment','bottom');
    
    set(h(1),'color','k','linewidth',1,'clipping','off');
    text(mean(X(3:6)),ast_line(1)+.03,sprintf('Adversity\nCategorization\nmodel'),'Rotation',0,'HorizontalAlignment','center','FontWeight','normal','fontname','Helvetica','fontsize',14,'verticalalignment','bottom');
    
    set(h(1),'color','k','linewidth',1,'clipping','off');
    text(mean(X(7:end)),ast_line(1)+.03,sprintf('Adversity\nTuning\nmodel'),'Rotation',0,'HorizontalAlignment','center','FontWeight','normal','fontname','Helvetica','fontsize',14,'verticalalignment','bottom');
    set(gcf,'Color',[1 1 1]);
    
    
    
    keyboard;
elseif strcmp(varargin{1},'get_table_behavior'); %% returns parameter of the behaviral recordings
    %%
    % Target: relate model betas (representing ellipsoidness) to subject's ratings and scr 'behavior'.
    % Steps:
    % collect necessary data
    % set up table
    force    = 0;
    p        = Project;
    subs     = FPSA_FearGen('get_subjects');
    path2table = sprintf('%sdata/midlevel/table_predict_behavior_N%d.mat',path_project,length(subs));
    
    if ~exist(path2table)||force == 1
        %% prepare scr data
        scrsubs  = ismember(subs,p.subjects(p.subjects_scr));
        scrpath  = sprintf('%sdata/midlevel/SCR_N%d.mat',path_project,sum(scrsubs));
        %get scr data
        if ~exist(scrpath)
            g        = Group(subs(scrsubs));
            out      = g.getSCR(2.5:5.5);
            save(scrpath,'out');
            clear g
        else
            load(scrpath)
        end
        scr_test_nonparam            = nan(length(subs),1); % the table needs same number of rows, so we just fill a column of nans with scr params.
        scr_test_nonparam(scrsubs,:) = mean(out.y(:,[21 22 23]),2)-mean(out.y(:,[25 26 19]),2); %% diff between CSP and CSN (IS THIS ZSCORED?) yes
        scr_test_cspcsn              = nan(length(subs),1); % the table needs
        scr_test_cspcsn(scrsubs,:)   = out.y(:,22)-out.y(:,26);
        
        %% scr data with fits
        ns = 0;
        scr_test_parametric            = nan(length(subs),1);
        for sub = subs(scrsubs(:)');
            ns                          = ns + 1;
            s                           = Subject(sub);
            bla(ns,1)                   = s.get_fit('scr',4).params(1);
        end
        scr_test_parametric(scrsubs,1) = bla;
        %% prepare rating data
        % collect rating amplitudes
        ns = 0;
        for sub = subs(:)'
            ns     = ns+1;
            s      = Subject(sub);
            rating = s.get_rating(4);
            %             Y      = zscore(rating.y);%zscored rating
            %             Y      = accumarray(rating.x'/45+4,Y,[8 1],@mean)';
            Y = rating.y_mean;
            %             amp_test_nonparam(ns,1)   =
            rating_test_parametric(ns,1) = s.get_fit('rating',4).params(1);
            rating_test_nonparam(ns,1)   = mean(Y([3 4 5]))-mean(Y([1 7 8]));
            rating_test_cspcsn(ns,1)     = Y(4)-Y(8);
        end
        %% get model parameters
        C          = FPSA_FearGen('FPSA_model_singlesubject',{'fix',1:100});
        beta1_base         = C.model_02.w1(:,1);
        beta2_base         = C.model_02.w2(:,1);
        beta1_test         = C.model_02.w1(:,2);
        beta2_test         = C.model_02.w2(:,2);
        beta1_diff         = C.model_02.w1(:,2)-C.model_02.w1(:,1);
        beta2_diff         = C.model_02.w2(:,2)-C.model_02.w2(:,1);
        beta_diff_test     = beta1_test - beta2_test;
        beta_diffdiff      = (beta1_test - beta2_test) - (beta1_base - beta2_base);%how much does w1 increase more than w2 does? (Interaction)
        %% concatenate everything in the table
        t = table(subs(:),rating_test_parametric,rating_test_nonparam,rating_test_cspcsn,scr_test_parametric,scr_test_nonparam,scr_test_cspcsn,beta1_base,beta2_base,beta1_test,beta2_test,beta1_diff,beta2_diff,beta_diff_test,beta_diffdiff,'variablenames',{'subject_id' 'rating_test_parametric','rating_test_nonparam','rating_test_cspcsn','scr_test_parametric','scr_test_nonparam','scr_test_cspcsn','beta1_base','beta2_base','beta1_test','beta2_test','beta1_diff','beta2_diff','beta_diff_test','beta_diffdiff'});
        save(path2table,'t');
    else
        fprintf('Found table at %s, loading it.\n',path2table)
        load(path2table);
    end
    %%
    varargout{1} = t;
elseif strcmp(varargin{1},'model_fpsa_testgaussian_optimizer');
    %% create Gaussian models with different parameters to find the best one to compare against the flexible model
    t           = FPSA_FearGen('FPSA_get_table',{'fix' 1:100});
    tsubject    = length(unique(t.subject));
    res         = 50;
    amps        = linspace(0.1,5,res);
    sds         = linspace(0.4,5,res);
    %%
    c           = 0;
    BIC2 = nan(res,1);
    for amp = (amps)
        for sd = (sds)
            c          = c + 1;
            fprintf('%d of %d finished...\n',c,res^2);
            %
            [cmat]     = getcorrmat(0,amp,0,amp,sd);
            %             imagesc(cmat,[-1 1]);
            %             colorbar;title('Currently fitted Gau component');drawnow;
            model3_g   = Vectorize(repmat(repmat(squareform_force(cmat),1,1),1,tsubject));%
            %
            t.gau      = model3_g(:);
            a          = fitlm(t,'FPSA_G ~ 1 + specific + unspecific + gau');
            BIC2(c)    = a.Rsquared.Ordinary;%a.ModelCriterion.BIC;
        end
    end
    %%
    BIC2         = reshape(BIC2,res,res);
    varargout{1} = BIC2;
    
    %% prepare the output;
    [y x]  = find(BIC2 == max(BIC2(:)));
    amp    = amps(x);
    sd     = sds(y);
    clf
    imagesc(amps,sds,reshape(BIC2,res,res));
    hold on
    plot(amp,sd,'ko','markersize',25);
    hold off;
    title( 'BIC = f(amp,sd)');
    xlabel('amp');
    ylabel('sd');
    fprintf('The best amplitude and sd parameters are as follows:\n AMP: %3.5g, SD: %3.5g\n',amp,sd);
    
elseif strcmp(varargin{1},'NvsO') %% compares neighboring correlation to opposing correlations
    %%
    % BLOCK = 1 | 2 for baseline | test, respectively
    sim   = varargin{2};
    block = varargin{3};
    r     = FPSA_FearGen('get_block',sim,block,block);
    for ns = 1:size(r,3)
        c.N(:,ns) = diag(r(:,:,ns),1);
        c.O(:,ns) = diag(r(:,:,ns),4);
    end
    varargout{1} = c;
    [h p stats bla] = ttest(fisherz(1-mean(c.N))-fisherz(1-mean(c.O)))
    
    
elseif strcmp(varargin{1},'FPSA_CompareB2T'); %% element-wise analysis of the FPSA matrix
    %% returns the coordinates and pvalue of the test comparing corresponding similarity entries of between baseline and generalization.
    %the full B and T similarity matrix;
    sim = FPSA_FearGen('get_fpsa_fair',{'fix',1:100},1:3);%
    %%we only want the B and T parts
    [~,B] = FPSA_FearGen('get_block',sim,1,1);
    [~,T] = FPSA_FearGen('get_block',sim,2,2);
    %fisher transform and make a ttest
    [h p ] = ttest(fisherz(B)-fisherz(T));
    h      = squareform_force(h);
    p      = squareform_force(p);
    [i]    = find(p < .05);
    p      = p(i);
    varargout{1} = [i p];
    
elseif strcmp(varargin{1},'numbers_fpsa_result')
    %% returns the coordinates and pvalue of the test comparing corresponding similarity entries of between baseline and generalization.
    %the full B and T similarity matrix;
    sim = FPSA_FearGen('get_fpsa_fair',{'fix',1:100},1:3);%
    %%we only want the B and T parts
    [~,B] = FPSA_FearGen('get_block',sim,1,1);
    [~,T] = FPSA_FearGen('get_block',sim,2,2);
    subs = FPSA_FearGen('get_subjects');
    nsubs = length(subs);
    
    for n = 1:nsubs;
        Bsquare(:,:,n) = squareform(B(n,:));
        Tsquare(:,:,n) = squareform(T(n,:));
    end
    %off diagonal averages
    for sc = 1:nsubs
        for ndiag = 1:7
            avediagB(ndiag,sc) = mean(diag(Bsquare(:,:,sc),ndiag));
            avediagT(ndiag,sc) = mean(diag(Tsquare(:,:,sc),ndiag));
        end
    end
    M_B   = mean(avediagB,2);
    SEM_B = std(avediagB,0,2)./sqrt(nsubs);
    M_T   = mean(avediagT,2);
    SEM_T = std(avediagT,0,2)./sqrt(nsubs);
    %
    
    
    %% Reporting Model fits:
    out      = FPSA_FearGen('FPSA_model',{'fix',1:100});
    %% on single subs:
    [C,~,MC]        = FPSA_FearGen('FPSA_model_singlesubject',{'fix',1:100});
    
    
    for modnum = 1:3
        for ph = 1:2
            for ns = 1:nsubs
                AIC(ns,ph,modnum) = MC(ns,ph,modnum).AIC;
                BIC(ns,ph,modnum) = MC(ns,ph,modnum).BIC;
            end
        end
    end


    %% print everything nicely
    clc
    %%
    %text: 1st and 4th
    fprintf(['direct neighbors: %04.2f ' char(177) ' %04.2f\n'],M_B(1),SEM_B(1))
    fprintf(['180 degrees: %04.2f ' char(177) ' %04.2f\n'],M_B(4),SEM_B(4))
    [h p ci stats] = ttest(avediagB(4,:),avediagB(1,:));
    fprintf('t-test: t(%d) = %04.2f, p = %06.5f\n\n.',stats.df,stats.tstat,p)
    %
    
    %S1 Table (baseline group fit mixed effects):
    %
    bic_null      = out.baseline.model_00_mixed.ModelCriterion.BIC;
    bic           = out.baseline.model_01_mixed.ModelCriterion.BIC;
    rsquared      = out.baseline.model_01_mixed.Rsquared.Adjusted;
    
    fprintf('Model parameters for Baseline, mixed effects:\n');
    fprintf('Rsquared adjusted: %05.2f \n BIC_null: %05.1f \n BIC: %05.1f \n',rsquared,bic_null,bic)
    %% single subs report
    fprintf('Model parameters for single subjects:\n');
    [h p ci stats] = ttest(C.model_01.w1(:,1));
    fprintf(['M = %05.3f' char(177) '%05.3f, t(%d) = %05.3f, p = %06.5f\n'],mean(C.model_01.w1(:,1)),std(C.model_01.w1(:,1))./sqrt(nsubs),stats.df,stats.tstat,p)
    %perceptual model baseline
    mean(BIC(:,1,1))
    std(BIC(:,1,1))./sqrt(length(BIC))

    %% S2 Table, (generalization, group fit mixed effects):
    out.generalization.model_01_mixed;
    %
    bic_null = out.generalization.model_00_mixed.ModelCriterion.BIC;
    bic      = out.generalization.model_01_mixed.ModelCriterion.BIC;
    rsquared =  out.generalization.model_01_mixed.Rsquared.Adjusted;
    fprintf('Model parameters for Generalization phase, mixed effects:\n');
    fprintf('Rsquared adjusted: %05.2f \n BIC_null: %05.1f \n BIC: %05.1f \n',rsquared,bic_null,bic)
    %% increase of model parameter from baseline to generalization:
    fprintf('Model parameters for single subjects:\n');
    [h p ci stats] = ttest(C.model_01.w1(:,2),C.model_01.w1(:,1));
    fprintf(['M = %05.3f' char(177) '%05.3f, t(%d) = %05.3f, p = %06.5f\n'],mean(C.model_01.w1(:,2)),std(C.model_01.w1(:,2))./sqrt(nsubs),stats.df,stats.tstat,p)
        %perceptual model testphase
    mean(BIC(:,2,1))
    std(BIC(:,2,1))./sqrt(length(BIC))

    %% Model comparison indicated that this model performed better than the bottom-up model
    fprintf('bottom-up vs adversity tuning model:\n');
    bic_bottomup     = out.generalization.model_01_mixed.ModelCriterion.BIC;
    bic_adv_Cat_tuning   = out.generalization.model_02_mixed.ModelCriterion.BIC;
    fprintf('BIC_bottomup= %05.1f, BIC_advtune= %05.1f\n Rsquared adjusted: %03.2f\n',bic_bottomup,bic_adv_Cat_tuning,out.generalization.model_02_mixed.Rsquared.Adjusted)
    %spec_unspec vs perceptual model testphase
    diffBIC = BIC(:,2,2)-BIC(:,2,1);
    mean(diffBIC)
    std(diffBIC)./sqrt(length(BIC))
    
    %% specific component stronger than unspecific component
    fprintf('Model parameters for single subjects:\n');
    [h p ci stats] = ttest(C.model_02.w1(:,2));
    fprintf(['Specific:   M = %05.3f' char(177) '%05.3f, t(%d) = %04.3f, p = %06.5f\n'],mean(C.model_02.w1(:,2)),std(C.model_02.w1(:,2))./sqrt(nsubs),stats.df,stats.tstat,p)
    [h p ci stats] = ttest(C.model_02.w2(:,2));
    fprintf(['Unspecific: M = %05.3f' char(177) '%05.3f, t(%d) = %04.3f, p = %06.5f\n'],mean(C.model_02.w2(:,2)),std(C.model_02.w2(:,2))./sqrt(nsubs),stats.df,stats.tstat,p)
    fprintf('Corresponds to factor: A = %03.2f\n',mean(C.model_02.w1(:,2))/mean(C.model_02.w2(:,2)));
    fprintf('---------------------------\n');
    fprintf('Specific versus unspecific:');
    [h p ci stats] = ttest(C.model_02.w1(:,2),C.model_02.w2(:,2));
    fprintf('  t(%d) = %04.3f, p = %06.5f\n',stats.df,stats.tstat,p)
    fprintf('No change from learning for unspecific component:');
    [h p ci stats] = ttest(C.model_02.w2(:,2),C.model_02.w2(:,1));
    fprintf('  t(%d) = %04.3f, p = %06.5f\n',stats.df,stats.tstat,p)
    %% change in dissimilarities:
    mean(Bsquare(4,8,:))
    std(Bsquare(4,8,:))/sqrt(nsubs)
    mean(Tsquare(4,8,:))
    std(Tsquare(4,8,:))/sqrt(nsubs)
    mean(Bsquare(2,6,:))
    std(Bsquare(2,6,:))/sqrt(nsubs)
    mean(Tsquare(2,6,:))
    std(Tsquare(2,6,:))/sqrt(nsubs)
    
    %% adversity categorization model better than adversity tuning model
    out.generalization.model_03_mixed;
    %
    bic_adv_Cat_tuning   = out.generalization.model_02_mixed.ModelCriterion.BIC;
    bic_adv_Tuning       = out.generalization.model_03_mixed.ModelCriterion.BIC;
    rsquared =  out.generalization.model_03_mixed.Rsquared.Adjusted;
    fprintf('Adversity categorization model better than adversity tuning model :\n');
    fprintf('Rsquared adjusted: %05.2f \nBIC_AdvCatTuning %05.1f \nBIC_AdvTuning: %05.1f \n',rsquared,bic_adv_Cat_tuning,bic_adv_Tuning)
    
    %spec_unspec model vs CS+ specific testphase
    diffBIC = BIC(:,2,2)-BIC(:,2,3);
    mean(diffBIC)
    std(diffBIC)./sqrt(length(BIC))

    %% the parameter estimates for the adversity component were not significantly different from zero neither in baseline or generalization phases
    w_gaussian = C.model_03.w3;
    fprintf('parameter estimates for single subjects not different from zero:\n');
    [h p ci stats] = ttest(w_gaussian(:,1));
    fprintf(['Baseline:                M = %05.3f' char(177) '%05.3f, t(%d) = %04.3f, p = %04.2f\n'],mean(w_gaussian(:,1)),std(w_gaussian(:,1))./sqrt(nsubs),stats.df,stats.tstat,p)
    [h p ci stats] = ttest(w_gaussian(:,2));
    fprintf(['Generalization phase:    M = %05.3f' char(177) '%05.3f, t(%d) = %04.3f, p = %04.2f\n'],mean(w_gaussian(:,2)),std(w_gaussian(:,2))./sqrt(nsubs),stats.df,stats.tstat,p)
    fprintf('Pairwise not different:  ');
    [h p ci stats] = ttest(w_gaussian(:,2),w_gaussian(:,1));
    fprintf('t(%d) = %04.3f, p = %04.2f\n',stats.df,stats.tstat,p)
    
    %%
    beta1_base         = C.model_02.w1(:,1);
    beta2_base         = C.model_02.w2(:,1);
    beta1_test         = C.model_02.w1(:,2);
    beta2_test         = C.model_02.w2(:,2);
    beta_diffdiff      = (beta1_test - beta2_test) - (beta1_base - beta2_base);%how much does w1 increase more than w2 does? (Interaction)
    
    subs1 = FPSA_FearGen('current_subject_pool',1,'get_subjects');
    subs0 = FPSA_FearGen('current_subject_pool',0,'get_subjects');
    % all subs
    sum(beta_diffdiff>0) % subs with anisotropy test > base
    sum(beta_diffdiff>0)./length(subs0)
    %pr
    binopdf(sum(beta_diffdiff>0),length(subs0),.5) %.5 for chance level.
    
    % learners only
    ind = ismember(subs0,subs1);
    sum(beta_diffdiff(ind)>0)
    sum(beta_diffdiff(ind)>0)./length(subs1)
    binopdf(sum(beta_diffdiff(ind)>0),length(subs1),.5) %.5 for chance level.
    
    %
    has_learned = ind;
    anis        = beta_diffdiff>0;
    [tbl chi2 pv]=crosstab(has_learned,anis);
    
    %%
    varargout{1} = out;
    varargout{2} = C;
    varargout{3} = sim;
    keyboard
    
elseif strcmp(varargin{1},'searchlight')
    %% conducts a searchlight analysis on the FDMs using a moving window of about 1 degrees
    % Default window parameters B1 and B2 are 1, and 15; (1 degree running
    % average windows with full overlap).
    % At each searchlight position the flexible model is fit.
    b1                = varargin{2};
    b2                = varargin{3};
    selector          = varargin{4};
    runs_per_phase{2} = 1;
    runs_per_phase{4} = runs;
    fun               = @(block_data) FPSA_FearGen('searchlight_fun_handle',block_data.data);%what we will do in every block
    
    runc             = 0;%1 run from B + 3 runs from T.
    for phase = [2 4];
        conds = condition_borders{phase};%default parameter
        for run = runs_per_phase{phase}
            runc             = runc + 1;
            fixmat           = FPSA_FearGen('current_subject_pool',current_subject_pool,'get_fixmat','runs',run);%get the fixmat for this run
            filename         = DataHash({fixmat.kernel_fwhm,b1,b2,phase,run,selector{:},current_subject_pool});
            subc = 0;
            for subject = unique(fixmat.subject);
                subc                 = subc + 1;%subject counter
                path_write           = sprintf('%s/data/sub%03d/p%02d/midlevel/%s.mat',path_project,subject,phase,filename);
                cprintf([1 0 0],'Processing subject %03d\ncache name: %s\n',subject,path_write);
                if exist(fileparts(path_write)) == 0;mkdir(fileparts(path_write));end;%create midlevel folder if not there.
                %analysis proper
                if exist(path_write) == 0 | force
                    % create the query cell
                    maps             = FPSA_FearGen('get_fixmap',fixmat,{'subject' subject selector{:}});
                    maps             = reshape(maps(:,conds),[500 500 length(conds)]);
                    out              = blockproc(maps,[b1 b1],fun,'BorderSize',[b2 b2],'TrimBorder', false, 'PadPartialBlocks', true,'UseParallel',true,'DisplayWaitbar',false);
                    save(path_write,'out');
                else
                    cprintf([0 1 0],'Already cached...\n');
                    load(path_write);
                end
                B1(:,:,:,subc,runc) = out;
            end
        end
    end
    varargout{1} = B1;
elseif strcmp(varargin{1},'searchlight_fun_handle')
    %% This is the function kernel executed for each seachlight position.
    
    maps = varargin{2};
    maps = reshape(maps,[size(maps,1)*size(maps,2) size(maps,3)]);
    if all(sum(abs(maps)))
        Y            = 1-pdist(maps','correlation');
        X            = FPSA_FearGen('searchlight_get_design_matrix');%returns the design matrix for the flexible ellipsoid model
        betas(1,1,:) = X\Y';
    else
        betas(1,1,:)= [NaN NaN NaN];
    end
    varargout{1} = betas;
elseif strcmp(varargin{1},'searchlight_get_design_matrix');
    %% Design matrix for the ellipsoide model.
    
    x          = [pi/4:pi/4:2*pi];
    w          = [cos(x);sin(x)];
    %
    model2_c   = squareform_force(cos(x)'*cos(x));
    model2_s   = squareform_force(sin(x)'*sin(x));
    X          = [ones(length(model2_c(:)),1) model2_c model2_s];
    varargout{1}  = X;
elseif strcmp(varargin{1},'figure_05BC') %'searchlight_plot'
    %% will spatially plot the ellipses area using the sqrt(cosine^2 +
    %sine^2) weight combination term.
    
    
    %     inputs = { {15 {}          'current_subject_pool' 0} {15 {}          'current_subject_pool' 1} ...
    %                {15 {'fix' 2:5} 'current_subject_pool' 0} {15 {'fix' 2:5} 'current_subject_pool' 1} ...
    %                {30 {'fix' 2:5} 'current_subject_pool' 0} {30 {'fix' 2:5} 'current_subject_pool' 1}};
    
    inputs = { {30 {'fix' 2:5} 'current_subject_pool' 1}};
    
    
    %              };RERUN THIS INCLUDING THE COMPUTED SHIT AND RERUN WITH THE
    %              NEW ROIS
    F = @(x) nanmean(x,4);
    for input = inputs;
        
        input{1}{:}
        current_title   = cell2str(input{1});
        filename        = sprintf('%s/data/midlevel/figures/searchlight_%s_fun_%s.png',path_project,current_title,func2str(F));
        filename2       = sprintf('%s/data/midlevel/figures/searchlight_%s_fun_%s_viafixmat.png',path_project,current_title,func2str(F));
        if (exist(filename) == 0) | (exist(filename2) == 0) | 1
            %to do
            %(1) compare all fixations on all subjects;+
            %(2) compare all fixations on selected subjects;+
            %(3) exclude the first fixation on all subjects.
            %(4) exclude the first fixation on selected subjects.
            %(5) exclude the first fixation on all subjects and test the bigger searchlight window.
            %(6) exclude the first fixation on selected subjects and test the
            %bigger searchlight window.
            
            
            Mori            = FPSA_FearGen('searchlight',1,input{1}{:});
            
            
            % MORI(pixel,pixel,regressor,subject,phase)
            M                = Mori;
            M(:,:,:,:,2)     = nanmean(Mori(:,:,:,:,2:end),5);%merge the 3 test runs.
            M(:,:,:,:,3:end) = [];
            M(:,:,1,:,:)     = [];%remove the intercept
            %     M                = mean(M,3);%compute the weight for the circular model.
            % plot the number of subjects present per pixel, get a mask
            figure(1);
            C = mean(mean(double(~isnan(M(:,:,1,:,1:2))),4),5)*100;
            imagesc(C,[0 100]);colorbar;hold on;
            contourf(C,[90 75 50],'fill','off');axis ij;hold off;
            axis off
            title('Counts');
            % remove the data outside of the mask
            M             = reshape(M,[500*500 2 size(Mori,4) 2]);
            mask          = C < 25;
            mask          = mask(:);
            M(mask,:,:,:) = NaN;
            %                  plot specific and unspecific components
            M             = reshape(M,[500 500 2 size(Mori,4) 2]);
            % plot specific and unspecific components
            ffigure;
            N   = 0;
            clf;
            d = -.12;u = .12;
            subplot(4,4,1);imagesc(squeeze(F(M(:,:,1,:,1))),[d u]);colorbar;title('Specific-Baseline')
            subplot(4,4,2);imagesc(squeeze(F(M(:,:,2,:,1))),[d u]);colorbar;title('unSpecific-Baseline')
            subplot(4,4,3);imagesc(squeeze(F(M(:,:,1,:,1)-M(:,:,2,:,1))),[d u]);colorbar;title('Specific-Unspecific')
            subplot(4,4,4);imagesc(squeeze(F(mean(M(:,:,1:2,:,1),3))),[d u]);colorbar;title('Circle-Baseline')
            
            subplot(4,4,5);imagesc(squeeze(F(M(:,:,1,:,2))),[d u]);colorbar;title('Specific-Test')
            subplot(4,4,6);imagesc(squeeze(F(M(:,:,2,:,2))),[d u]);colorbar;title('unSpecific-Test')
            subplot(4,4,7);imagesc(squeeze(F(M(:,:,1,:,2)-M(:,:,2,:,2))),[d u]);colorbar;title('Specific-Unspecific')
            subplot(4,4,8);imagesc(squeeze(F(mean(M(:,:,1:2,:,2),3))),[d u]);colorbar;title('Circle-Test')
            
            subplot(4,4,9);imagesc(squeeze(F(M(:,:,1,:,2)-M(:,:,1,:,1))),[d u]);colorbar;title('Diff')
            subplot(4,4,10);imagesc(squeeze(F(M(:,:,2,:,2)-M(:,:,2,:,1))),[d u]);colorbar;title('Diff')
            subplot(4,4,11);imagesc( squeeze(F(M(:,:,1,:,2)-M(:,:,2,:,2)))  - squeeze(F(M(:,:,1,:,1)-M(:,:,2,:,1)))  , [d u]);colorbar;title('Diff')
            subplot(4,4,12);imagesc(squeeze(F(mean(M(:,:,1:2,:,2),3)-mean(M(:,:,1:2,:,1),3))),[d u]);colorbar;title('Diff')
            supertitle(current_title,1,'fontsize',16,'fontweight','bold','interpreter','none');
            % count the beta values from 4 rois
            C = [];
            r = Fixmat([],[]).GetFaceROIs;
            r = sum(reshape(r,250000,4));
            for np = 1:size(M,5)
                for ns = 1:size(M,4)
                    for w = 1:size(M,3)
                        C(ns,:,w,np) = Fixmat([],[]).EyeNoseMouth(M(:,:,w,ns,np),0)./r;%(pixel,pixel,regressor,subject,phase)
                        %[subject, roi, predictor, phase]
                    end
                end
            end
            C(:,4,:,:) = [];
            %%
            labels = {'eyes' 'nose' 'mouth'};
            %C = [subject roi predictor phase]
            subplot(4,4,13);
            D  = (C(:,:,1,2)-C(:,:,1,1));%Specific Test - Specific Baseline
            barplot_deluxe(D,labels);
            
            subplot(4,4,14)
            D  = (C(:,:,2,2)-C(:,:,2,1));%Unspecific Test  - Unspecific Baseline
            barplot_deluxe(D,labels );
            
            subplot(4,4,15);
            D  = (C(:,:,1,2)-C(:,:,2,2))-(C(:,:,1,1)-C(:,:,2,1));%Specific-Unspecific between two phases
            barplot_deluxe(D,labels );
            
            %                  SaveFigure(filename,'-r300');
            
            %% plot the same thing as below with Fixmat object
            figure;
            fix             = Fixmat([],[]);
            fix.cmap_limits = [-.2 .2];
            
            %plot specific/unspecific Baseline and test as a 2x2
            %figure
            fix.maps        = cat(3,squeeze(F(M(:,:,2,:,1))),squeeze(F(M(:,:,2,:,2))),squeeze(F(M(:,:,1,:,1))),squeeze(F(M(:,:,1,:,2))))
            H = fix.plot;
            for n = 1:length(H);
                axes(H(n));axis on;set(gca,'xticklabel','','yticklabel','','xgrid','on','ygrid','on');
                Publication_RemoveXaxis(gca);
                Publication_RemoveYaxis(gca)
            end
            subplotChangeSize(H,.04,.04)
            set(gcf,'position',[ 2011         357         671         604])
            
            H(1).YLabel.String = 'Unspecific';
            H(1).YLabel.FontWeight = 'bold';
            H(3).YLabel.String = 'Specific';
            H(3).YLabel.FontWeight = 'bold';
            H(3).YLabel.FontSize   = 16;
            H(1).YLabel.FontSize   = 16;
            %%
            figure;
            D  = (C(:,:,1,2)-C(:,:,2,2))-(C(:,:,1,1)-C(:,:,2,1));%Specific-Unspecific between two phases
            [h p] =barplot_deluxe(D,labels );
            Publication_Ylim(gca,2,1)
            Publication_NiceTicks(gca,2);
            Publication_FancyYticks(gca,.05)
            Publication_RemoveXaxis(gca);
            set(gca,'xlim',[0.25 max(xlim)])
            ylabel('\Delta_{test} - \Delta_{baseline}','fontsize',16)
            %%
            SaveFigure(filename2,'-r300');
            
        else
            fprintf('%s: Computed already',filename)
            pause(4)
        end
        
        
    end
    %%
    %     G       = [ repmat(Vectorize(repmat(1:4,74,1)),4,1) repmat(Vectorize(repmat([0 0 0 0 1 1 1 1],74,1)),2,1) repmat(Vectorize(repmat([0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1],74,1)),1,1) ];
    %     anovan(Vectorize(C(:,1:4,1:2,1:2)),G,'model','interaction')
    %     %%
    %     G       = [ repmat(Vectorize(repmat(1:4,74,1)),2,1) repmat(Vectorize(repmat([0 0 0 0 1 1 1 1],74,1)),1,1) ];
    %     anovan(Vectorize(C(:,1:4,1:2,2)-C(:,1:4,1:2,1)),G,'model','interaction')
    %     %%
    %     F  = [];
    %     CF = [];
    %     for phase = [2 4]
    %         %
    %         M = [];
    %         for deltacsp = [0 180]
    %             c = 0;
    %             v = [];
    %             for subjects = unique(fixmat.subject)
    %                 c    = c+1;
    %                 v{c} = {'subject' subjects 'phase' phase 'deltacsp',[deltacsp] 'start' 300:1500};
    %             end
    %             fixmat.getmaps(v{:});
    %             M{deltacsp+1} = fixmat.maps;
    %         end
    %         M = M{1} - M{181};
    %         %
    %         CF2 = [];
    %         for subjects = 1:size(fixmat.maps,3)
    %             CF2 = [CF2; fixmat.EyeNoseMouth(M(:,:,subjects))];
    %         end
    %         CF = cat(3,CF,CF2);
    %         F  = cat(3,F,mean(M,3));
    %     end
    %     %%
    %     ttest(CF(:,:,2)-CF(:,:,1))
    %     figure;bar(mean(CF(:,:,2)-CF(:,:,1)))
    %     %%
    %     fixmat.maps = F(:,:,2)-F(:,:,1);
    %     figure;fixmat.plot;
    %     %%
    %     fixmat.getmaps(v{:});
    %
    %     %%
    %     %     subplot(3,2,5);imagesc(squeeze(F(M(:,:,1,:,2))-F(M(:,:,1,:,1))),[d u]);colorbar;
    %     %     subplot(3,2,6);imagesc(squeeze(F(M(:,:,2,:,2))-F(M(:,:,2,:,1))),[d u]);colorbar;
    %
    %     fix             = Fixmat([],[]);
    %     fix.cmap_limits = 5;
    %     fix.maps        = reshape(squeeze(nanmedian(M(:,:,:,:,:),4)),[500 500 size(M,3)*size(M,5)]);
    %     fix.plot;
    %     colormap jet
    %     subplot(2,2,1);title('Specific - Baseline');subplot(2,2,2);title('unSpecific - Baseline');subplot(2,2,3);title('Specific - Generalization');subplot(2,2,4);title('unSpecific - Generalization');
    %     %% plot the differences
    %     figure(2);
    %     N               = 0;
    %     fix             = Fixmat([],[]);
    %     Mdiff           = cat(3,nanmedian(M(:,:,1,:,2)-M(:,:,1,:,1),3),nanmedian(M(:,:,2,:,2)-M(:,:,2,:,1),3));
    %     fix.maps        = Mdiff;
    %     fix.plot;
    %     colormap jet
    %     %     subplot(2,2,1);title('Specific - Baseline');subplot(2,2,2);title('unSpecific - Baseline');subplot(2,2,3);title('Specific - Generalization');subplot(2,2,4);title('unSpecific - Generalization');
    %     %% make a ttest
    %     M2      = reshape(M,[500*500 2 74 2]);%[pixel regressor subject phase];
    %     Md     = squeeze(M2(:,1,:,2)-M2(:,1,:,1));%-(M(:,2,:,2)-M(:,2,:,1)));
    %     [h p]  = q;
    %
    %     fix.maps = cat(3,reshape(h,500,500),reshape(-log10(p),500,500));
    %     fix.plot;
    %     %% make a signtest
    %     M     = reshape(M,[500*500 2 74 2]);
    %     h     = nan(250000,1);p = h;
    %     nbeta = 1;
    %     for npix = 1:250000;
    %         if mask(npix) == 0
    %             npix
    %             data              = squeeze(M(npix,nbeta,:,2)-M(npix,nbeta,:,1));
    %             %             [h(npix) p(npix)] = signtest( data(:));
    %             [p(npix) h(npix)] = signtest( data(:));
    %         end
    %     end
    %     fix.maps  = reshape([h(:) -log10(p(:))],[500 500 2]);
    %     imagesc(fix.maps(:,:,2));
    %     fix.plot;
    %     %%
    %     tuned         = ismember(FPSA_FearGen('get_subjects'),FPSA_FearGen('current_subject_pool',1,'get_subjects'))'
    %     M             = reshape(M,[500*500 2 74 2]);
    %     p             = nan(250000,1);
    %     h             = nan(250000,1);
    %     for i             = 1:250000;
    %         if mask(i) == 0
    %             data          = reshape(permute( squeeze(M(i,:,:,:)),[2 3 1]),[74 4]);%(subjects,phase,betas)
    %             %             G             = [Vectorize([zeros(74,2) ones(74,2)]) Vectorize([zeros(74,1) ones(74,1) zeros(74,1) ones(74,1)])];
    %             %             p(i,:)        = anovan(data(:),G,'model','interaction','display','off');
    %             %             data          = (data(:,2)-data(:,1))-(data(:,4)-data(:,3));
    %             data          = (data(tuned ,2)-data(tuned ,1));%-(data(tuned ,4)-data(tuned ,3));
    %             [h(i,1) p(i,1)] = signrank(data);
    %
    %         end
    %     end
    %
elseif strcmp(varargin{1},'searchlight_stimulus')
    %% applies the search light analysis to the V1 representations.
    b1          = varargin{2};
    b2          = varargin{3};
    noise_level = varargin{4};
    filename    = 'stimulus_searchlight';
    path_write  = sprintf('%sdata/midlevel/%s_noiselevel_%02d.mat',path_project,filename,noise_level);
    fun         = @(block_data) FPSA_FearGen('fun_handle',block_data.data);%what we will do in every block
    maps        = [];
    for n = 1:8
        maps(:,:,n) = imread(sprintf('%sstimuli/%02d.bmp',path_project,n));
    end
    obj  = Fixmat([],[]);
    maps = maps + rand(size(maps))*noise_level;
    maps = maps( obj.rect(1):obj.rect(1)+obj.rect(3)-1,  obj.rect(2):obj.rect(2)+obj.rect(4)-1,:);
    
    if exist(path_write) == 0
        % create the query cell
        out              = blockproc(maps,[b1 b1],fun,'BorderSize',[b2 b2],'TrimBorder', false, 'PadPartialBlocks', true,'UseParallel',true);
        save(path_write,'out');
    else
        cprintf([0 1 0],'Already cached...\n');
        load(path_write);
    end
    varargout{1} = out;
    %
    %     subplot(1,2,1);
    figure;
    imagesc(out(:,:,2));
    %     hold on
    %     f   = Fixmat([],[]);
    %     roi = f.GetFaceROIs;
    %     [~,h] = contourf(mean(roi(:,:,1:4),3));
    %     h.Fill = 'off';
    %     axis image;
    %     hold off;
    %     subplot(1,2,2);
    %     b = f.EyeNoseMouth(out(:,:,2),0)
    %     bar(b(1:4));
elseif strcmp(varargin{1},'searchlight_beta_counts')
    %% counts searchlight values in face rois
    fixmat      = FPSA_FearGen('get_fixmat');
    b1          = 1;
    b2          = 15;
    %     out         = FPSA_FearGen('searchlight',fixmat,b1,b2)
    out         = FPSA_FearGen('searchlight',b1,b2);
    for np = 1:2
        for ns = 1:size(out,4);
            for beta = 2%1:size(out,3)
                map            = out(:,:,beta,ns,np);
                count(ns,:,np) = fixmat.EyeNoseMouth(map,0);
            end
        end
    end
    varargout{1} = count;
    cr           = count;
    mean((cr(:,1,1)-cr(:,2,1))-(cr(:,1,2)-cr(:,2,2)))
elseif strcmp(varargin{1},'searchlight_anova')
    %%
    fixmat   = FPSA_FearGen('get_fixmat');
    cr       = FPSA_FearGen('searchlight_beta_counts',fixmat,1,15);
    tsubject = length(unique(fixmat.subject))
    
    Y        = [cr(:,1,1) cr(:,2,1) cr(:,1,2) cr(:,2,2)];
    figure;
    errorbar(mean(Y),std(Y)./sqrt(size(Y,1)));
    y        = [cr(:,1,1);cr(:,2,1);cr(:,1,2);cr(:,2,2)];
    side     = [ones(tsubject,1);ones(tsubject,1)*2;ones(tsubject,1);ones(tsubject,1)*2];
    phase    = [ones(tsubject,1);ones(tsubject,1);ones(tsubject,1)*2;ones(tsubject,1)*2];
    anovan(y,{side(:) phase(:)},'model','full')
    
elseif strcmp(varargin{1},'eyebehave_params') %outdated
    
    savepath = sprintf('%s/data/midlevel/',path_project);
    filename = 'eyebehave_params.mat';
    subs = FPSA_FearGen('get_subjects');
    
    visualization = 1; %if you want all plots to be created
    
    if nargin > 1
        force = varargin{2};
    end
    
    if ~exist([savepath filename]) || force == 1
        
        fix = Fixmat(subs,[2 3 4]);
        
        %mean number of fixations for this combination
        [d.fixN.data, d.fixN.info] = fix.histogram;
        dummy = [];
        dummy2 = [];
        
        sc = 0;
        for sub = unique(fix.subject)
            fprintf('\nWorking on sub %02d, ',sub)
            sc= sc+1;
            pc = 0;
            for ph = 2:4
                fprintf('phase %d. ',ph)
                pc = pc+1;
                cc=0;
                for cond = unique(fix.deltacsp)
                    cc=cc+1;
                    ind = logical((fix.subject==sub).*(fix.phase == ph).* (fix.deltacsp == cond));
                    %mean duration of fixations for this phase/sub/cond
                    d.fixdur.m(sc,pc,cc) = mean(fix.stop(ind)-fix.start(ind));
                    %% for entropy, we need single trials, otherwise the trial number contributing to mean FDM (for this cond-phase-sub) biases the entropy computation
                    %mean entropy for this combination
                    fix.unitize = 0;
                    tc = 0;
                    for tr = unique(fix.trialid(ind)) %loop through trials of this cond-phase-sub
                        tc = tc+1;
                        fix.getmaps({'trialid' tr 'phase' ph 'subject' sub 'deltacsp' cond});
                        dummy(tc) = FPSA_FearGen('FDMentropy',fix.vectorize_maps);
                        dummy2(tc) = entropy(fix.vectorize_maps);
                    end
                    d.FDMentropy.m(sc,pc,cc) = mean(dummy);
                    d.entropy.m(sc,pc,cc) = mean(dummy2);
                    fix.unitize = 1;
                    dummy = [];
                    dummy2 = [];
                end
            end
        end
        save([savepath filename],'d','subs');
    else
        load([savepath filename]);
    end
    
    varargout{1} = d;
    
    if visualization ==1
        subtitles = {'base','cond','test'};
        %% Number of fixations per condition and phase
        figure('Name','Fix Number');
        meancorr = 1;
        for n=1:3;
            if meancorr  == 1
                data = squeeze(d.fixN.data(:,:,n)) - repmat(nanmean(d.fixN.data(:,:,n),2),1,size(d.fixN.data,2));
            else
                data = squeeze(d.fixN.data(:,:,n));
            end
            
            subplot(2,3,n);
            boxplot(data);
            set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',60,'fontsize',14);
            title(subtitles{n})
            box off
            if meancorr ==1
                ylabel('N fixations (subj.mean corr.)')
            else
                ylabel('N fixations')
            end
            axis square
            subplot(2,3,n+3)
            Project.plot_bar(-135:45:315,nanmean(data),nanstd(data)./sqrt(length(subs)));
            set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',60,'fontsize',14);
            if n~=2
                td.x = repmat(-135:45:180,length(subs),1);
                td.y = data(:,1:8);
                td.ids = subs;
                t = Tuning(td);t.GroupFit(3);
                if (10.^-t.groupfit.pval)<.05
                    plot(t.groupfit.x_HD,[t.groupfit.fit_HD],'k','LineWidth',2)
                else
                    plot(linspace(-180,270,1000),repmat(mean(t.y_mean),1,1000),'k-','LineWidth',2)
                end
                title(sprintf('p = %04.2f',10.^-t.groupfit.pval));
            end
            box off
            if meancorr ==1
                ylabel('N fixations (subj.mean corr.)')
            else
                ylabel('N fixations')
            end
            axis square
        end
        for n = 4:6
            subplot(2,3,n)
            ylim([min(mean(data))-.5 max(mean(data))+.7])
            %             ylim([nanmean(d.fixN.data(:))-nanstd(d.fixN.data(:)) nanmean(d.fixN.data(:))+nanstd(d.fixN.data(:))])
        end
        %% Fixation durations per condition
        figure('Name','Fix Duration');
        meancorr = 1;
        for n=1:3;
            if meancorr  ==1
                data = squeeze(d.fixdur.m(:,n,:)) - repmat(nanmean(d.fixdur.m(:,n,:),3),1,size(d.fixdur.m,3));
            else
                data = squeeze(d.fixdur.m(:,n,:));
            end
            subplot(2,3,n);
            boxplot(data);
            set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',60,'fontsize',14);
            title(subtitles{n})
            box off
            ylabel('fix duration [ms]')
            axis square
            subplot(2,3,n+3)
            Project.plot_bar(-135:45:315,nanmean(data),nanstd(data)./sqrt(length(subs)));
            set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',60,'fontsize',14);
            box off
            ylabel('fix duration [ms]')
            axis square
            if n~=2
                td.x = repmat(-135:45:180,length(subs),1);
                td.y = data(:,1:8);
                td.ids = subs;
                t = Tuning(td);t.GroupFit(3);
                if (10.^-t.groupfit.pval)<.05
                    plot(t.groupfit.x_HD,[t.groupfit.fit_HD],'k','LineWidth',2)
                else
                    plot(linspace(-180,270,1000),repmat(mean(t.y_mean),1,1000),'k-','LineWidth',2)
                end
                title(sprintf('p = %04.2f',10.^-t.groupfit.pval));
            end
        end
        for n = 4:6
            subplot(2,3,n)
            ylim([nanmean(data(:))-nanstd(data(:)) nanmean(data(:))+nanstd(data(:))])
        end
        %% difference of fixation durations between test and baseline
        figure('Name','Fix Duration T-B');
        diffTB = squeeze(d.fixdur.m(:,3,:)-d.fixdur.m(:,1,:)); % this is practically meancorrected for the sub then.. we just look at the difference.
        subplot(1,2,1)
        boxplot(diffTB);
        set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',60,'fontsize',14);
        hold on;
        line(xlim,[0 0])
        box off
        ylabel('duration diff Test-Base [ms]')
        axis square
        subplot(1,2,2)
        Project.plot_bar(-135:45:315,nanmean(diffTB),nanstd(diffTB)./sqrt(length(subs)));
        set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',60,'fontsize',14);
        hold on;
        line(xlim,[0 0])
        box off
        ylabel('duration diff Test-Base [ms]')
        axis square
        if n~=2
            td.x = repmat(-135:45:180,length(subs),1);
            td.y = diffTB(:,1:8);
            td.ids = subs;
            t = Tuning(td);t.GroupFit(3);
            if (10.^-t.groupfit.pval)<.05
                plot(t.groupfit.x_HD,[t.groupfit.fit_HD],'k','LineWidth',2)
            else
                plot(linspace(-180,270,1000),repmat(mean(t.y_mean),1,1000),'k-','LineWidth',2)
            end
            title(sprintf('p = %04.2f',10.^-t.groupfit.pval));
        end
        %% Entropy of fixmaps per condition, sub and phase (matlab entropy)
        figure('Name','Matlabs Entropy');
        meancorr = 1;
        for n = 1:3;
            if meancorr  ==1
                data = squeeze(d.FDMentropy.m(:,n,:)) - repmat(nanmean(d.FDMentropy.m(:,n,:),3),1,size(d.FDMentropy.m,3));
            else
                data = squeeze(d.FDMentropy.m(:,n,:));
            end
            subplot(2,3,n);
            boxplot(data);
            set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',45,'fontsize',14);
            title(subtitles{n})
            box off
            ylabel('FDM entropy [a.u.]')
            axis square
            subplot(2,3,n+3);
            Project.plot_bar(-135:45:315,nanmean(data),nanstd(data)./sqrt(length(subs)));
            set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',45,'fontsize',14);
            box off
            ylabel('FDM entropy [a.u.]')
            axis square
            if meancorr == 1 && n~=2
                subplot(2,3,n+3)
                dada.x = repmat(-135:45:180,74,1);
                dada.y = data(:,1:8)*1000; % Tuning obj not working for such small numbers.
                dada.ids = 1:74;
                t = Tuning(dada);t.GroupFit(3);
                hold on;
                if (10.^-t.groupfit.pval)<.05
                    plot(t.groupfit.x_HD,[t.groupfit.fit_HD]./1000,'k','LineWidth',2)
                else
                    plot(linspace(-180,270,1000),repmat(mean(t.y_mean)./1000,1,1000),'k-','LineWidth',2)
                end
                title(sprintf('p = %04.2f',10.^-t.groupfit.pval));
            end
            
        end
        for n = 4:6
            subplot(2,3,n)
            ylim([nanmean(data(:))-nanstd(data(:)) nanmean(data(:))+nanstd(data(:))])
        end
        
        
        % %        %% Entropy of fixmaps per condition, sub and phase (own entropy)
        % %        function E = FDMentropy(fdm)
        % %        % computes entropy of a fixation density map.
        % %        % Map should be normalized anyway. If not, this function does it.
        % %
        % %        % remove zero entries in p
        % %        fdm(fdm==0) = [];
        % %
        % %        if sum(fdm) ~=0
        % %            % normalize p so that sum(p) is one.
        % %            fdm = fdm ./ numel(fdm);
        % %        end
        % %
        % %        E = -sum(fdm.*log2(fdm));
        % %        end
        %
        %     figure(5);
        %     for n=1:3;
        %         subplot(2,3,n);
        %         boxplot(squeeze(d.FDMentropy.m(:,n,:)));
        %         set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',45,'fontsize',14);
        %         title(subtitles{n})
        %         box off
        %         ylabel('FDM entropy [a.u.]')
        %         axis square
        %         subplot(2,3,n+3);
        %         Project.plot_bar(-135:45:315,nanmean(squeeze(d.FDMentropy.m(:,n,:))),nanstd(squeeze(d.FDMentropy.m(:,n,:)))./sqrt(length(unique(fix.subject))));
        %         set(gca,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-' 'UCS' 'Odd' 'Null'},'XTickLabelRotation',45,'fontsize',14);
        %         box off
        %         ylabel('FDM entropy [a.u.]')
        %         axis square
        %     end
        %     for n = 4:6
        %         subplot(2,3,n)
        %         ylim([nanmean(d.FDMentropy.m(:))-nanstd(d.FDMentropy.m(:)) nanmean(d.FDMentropy.m(:))+nanstd(d.FDMentropy.m(:))])
        %     end
        
        %%
        figure('Name','Between Runs');
        colors = GetFearGenColors;
        colors = [colors; .8 .8 .8];
        set(0,'DefaultAxesColorOrder',colors);
        subplot(1,3,1)
        title('Num Fixations','fontsize',14);hold on
        errorbar([repmat(1:3,11,1)'+rand(3,11)*.2],squeeze(mean(d.fixN.data))',squeeze(nanstd(d.fixN.data))'./sqrt(length(d.fixN.data)),'LineWidth',1.5,'LineStyle',':')
        box off;
        axis square;
        ylabel('Num Fixations M/SEM')
        subplot(1,3,2)
        title('Fixation duration','fontsize',14);hold on
        errorbar([repmat(1:3,11,1)+rand(11,3)*.2]',squeeze(mean(d.fixdur.m)),squeeze(nanstd(d.fixdur.m))./sqrt(length(d.fixdur.m)),'LineWidth',1.5,'LineStyle',':')
        box off;
        axis square;
        ylabel('Fixation duration[ms] M/SEM')
        subplot(1,3,3)
        title('Entropy','fontsize',14);hold on
        errorbar([repmat(1:3,11,1)+rand(11,3)*.2]',squeeze(mean(d.entropy.m)),squeeze(nanstd(d.entropy.m))./sqrt(length(d.entropy.m)),'LineWidth',1.5,'LineStyle',':')
        box off;
        axis square;
        ylabel('FDM entropy [a.u.] M/SEM')
        legend({'-135','-90','-45','CS+','45','90','135','CS-','UCS','Odd','Null'},'fontsize',14,'location','best')
    end
elseif strcmp(varargin{1},'inter-subject-variance')
    
    subs = FPSA_FearGen('get_subjects');
    
    pc = 0;
    for ph = 2:4
        pc = pc+1;
        sc = 0;
        for sub = unique(subs)
            sc = sc+1;
            fix = Fixmat(sub,ph);
            cc = 0;
            for cond = fix.realcond
                cc = cc+1;
                ind = fix.deltacsp == cond;
                tc = 0;
                for tr = unique(fix.trialid(ind)) %loop through trials of this cond-phase-sub
                    tc = tc+1;
                    fix.getmaps({'trialid' tr 'phase' ph 'subject' sub 'deltacsp' cond});
                    dummy(tc) = FDMentropy(fix.vectorize_maps);
                    dummy2(tc) = entropy(fix.vectorize_maps);
                end
            end
        end
        fix.getsubmaps;
        submaps  = fix.maps;
        groupave = mean(submaps,3);
        fix.maps = [submaps - repmat(groupave,1,1,length(subs))];
        fix.maps = imresize(fix.maps,.1,'method','bilinear');
        
        ISV(pc,:) = var(fix.vectorize_maps);
        
    end
    
elseif strcmp(varargin{1},'SVM')
    %This script trains a linear SVM training CS+ vs. CS- for phases 2 and 4.
    %It collects the data and computes the eigenvalues on the
    %fly for chosen(or a range of parameters) (kernel_fwhm, number of
    %eigenvalues). As the number of trials are lower in the
    %baseline, all the test-training sessions should use the same number of
    %trials. For example to keep the comparisons comparable, in baseline 11
    %trials in the baseline, with .5 hold-out, one needs to sample the same
    %number of trials from the testphase before training.
    %the option random = 1 randomizes labels to determine the chance classification
    %performance level.
    random = 0;
    exclmouth = 1;
    tbootstrap       = 1000; %number of bootstraps
    phase            = [2 4 4 4];%baseline = 2, test = 4
    holdout_ratio    = .5; %holdout_ratio for training vs. test set
    teig             = 100; %up to how many eigenvalues should be included for tuning SVM?
    crit             = 'var';%choose 'ellbow' classification or 'var' 90% variance explained.
    cutoffcrit       = .9;
    R                = [];%result storage for classification performance
    HP               = [];%result storage for single subject hyperplanes.
    AVEHP            = [];%result storate for average hyperplane
    
    eigval           = [];
    trialselect      = {1:120 1:120 121:240 241:360};
    
    
    subjects = FPSA_FearGen('get_subjects');
    o = 0;
    for run = 1:4 % phase 2, phase 4.1 phase 4.2 phase 4.3
        o = o+1;
        fix             = Fixmat(subjects,phase(run));%get the data
        if exclmouth == 1
            roi = fix.GetFaceROIs;
        end
        fix.unitize     = 1;%unitize fixmaps or not (sum(fixmap(:))=0 or not).
        %% get number of trials per condition and subject: Sanity check...
        M               = [];%this will contain number of trials per subject and per condition. some few people have 10 trials (not 11) but that is ok. This is how I formed the subject_exlusion variable.
        sub_c           = 0;
        for ns = subjects(:)'
            sub_c = sub_c + 1;
            nc = 0;
            for cond = unique(fix.deltacsp)
                nc          = nc +1;
                i           = ismember(fix.phase,phase(run)).*ismember(fix.subject,ns).*ismember(fix.deltacsp,cond);%this is on fixation logic, not trials.
                i           = logical(i);
                M(sub_c,nc,o) = length(unique(fix.trialid(i)));
            end
        end
        %% get all the single trials in a huge matrix D together with labels.
        global_counter = 0;
        clear D;%the giant data matrix
        clear labels;%and associated labels.
        for ns = subjects(:)'
            for deltacsp = -135:45:180;
                i              = ismember(fix.trialid,trialselect{run}).*(fix.subject == ns).*(fix.deltacsp == deltacsp);
                trials         = unique(fix.trialid(i == 1));
                trial_counter  = 0;
                for trialid = trials
                    trial_counter       = trial_counter + 1;
                    global_counter      = global_counter +1;
                    c                   = global_counter;
                    v                   = {'subject' ns 'deltacsp' deltacsp 'trialid' trialid};
                    fix.getmaps(v);
                    if exclmouth == 1
                        fix.maps(roi(:,:,4)) = 0;
                    end
                    D(:,c)              = Vectorize(imresize(fix.maps,.1));
                    labels.sub(c)       = ns;
                    labels.phase(c)     = phase(run);
                    labels.trial(c)     = trial_counter;%some people have less trials check it out with plot(labels.trial)
                    labels.cond(c)      = deltacsp;
                end
            end
        end
        %% DATA2LOAD get the eigen decomposition: D is transformed to TRIALLOAD
        fprintf('starting covariance computation\n')
        covmat    = cov(D');
        fprintf('done\n')
        fprintf('starting eigenvector computation\n')
        [e dv]    = eig(covmat);
        fprintf('done\n')
        dv        = sort(diag(dv),'descend');
        eigval(:,run) = dv;
        %     figure(100);
        %     plot(cumsum(dv)./sum(dv),'o-');xlim([0 200]);drawnow
        eigen     = fliplr(e);
        %collect loadings of every trial
        trialload = D'*eigen(:,1:teig)*diag(dv(1:teig))^-.5;%dewhitened
        %% LIBSVM business
        neigs = [7 12 8 10]; %check eigenvalues and put numbers of EV here, based on ellbow criterion.
        if strcmp(crit,'ellbow')
            neig = neigs(run);
        elseif strcmp(crit,'var')
            neig = find(cumsum(dv)./sum(dv)>cutoffcrit,1,'first');
        end
        sub_counter = 0;
        result      = [];
        w           = [];
        for sub = unique(labels.sub)%go subject by subject
            fprintf('run:%d-Eig:%d-Sub:%d\n',run,neig,sub);
            if random == 1
                warning('Randomizing labels as wanted. \n')
            end
            sub_counter = sub_counter + 1;
            ind_all     = ismember(labels.sub,sub);%this subject, this phase.
            %
            for n = 1:tbootstrap%
                Ycond   = double(labels.cond(ind_all))';%labels of the fixation maps for this subject in this phase.
                X       = trialload(ind_all,1:neig);%fixation maps of this subject in this phase.
                % now normal Holdout for every phase (which should all have the
                % same number of trials now)
                P       = cvpartition(Ycond,'Holdout',holdout_ratio); % divide training and test datasets respecting conditions
                i       = logical(P.training.*ismember(Ycond,[0 180]));%train using only the CS+ and CS? conditions.
                if random ==1
                    model   = svmtrain(Shuffle(Ycond(i)), X(i,1:neig), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
                else
                    model   = svmtrain(Ycond(i), X(i,1:neig), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
                end
                % get the hyperplane
                try
                    w(:,sub_counter,n)          = model.SVs'*model.sv_coef;
                catch
                    keyboard%sanity check: stop if something is wrong
                end
                %%
                cc=0;
                for cond = unique(Ycond)'
                    cc                          = cc+1;
                    i                           = logical(P.test.*ismember(Ycond,cond));%find all indices that were not used for training belonging to COND.
                    [~, dummy]                  = evalc('svmpredict(Ycond(i), X(i,:), model);');%doing it like this supresses outputs.
                    dummy                       = dummy == 0;%binarize: 1=CS+, 0=Not CS+
                    result(cc,n,sub_counter)    = sum(dummy)/length(dummy);%get the percentage of CS+ responses for each CONDITION,BOOTSTR,SUBJECT
                end
            end
        end
        %once the data is there compute relevant output metrics:
        R(:,run)      = mean(mean(result,2),3);%average across bootstaps the classification results
        AVEHP(:,:,run) = reshape(mean(eigen(:,1:neig)*mean(w,3),2),[50 50 1]);%average hyperplane across subjects
        HP(:,:,:,run) = reshape(eigen(:,1:neig)*mean(w,3),[50 50 size(eigen(:,1:neig)*mean(w,3),2)]); %single hyperplanes
        
        savepath = sprintf('%s/data/midlevel/SVM/',path_project);
        filename = sprintf('/SVM_NEV%d_FWHM30_r%d_run%d_crit%s_exclmouth_%d.mat',neig,random,run,crit,exclmouth);
        if exist(savepath)
            save([savepath filename],'neig','R','eigval','result','HP','AVEHP');
        else
            fprintf('Creating SVM results folder...\n')
            mkdir(savepath);
            save([savepath filename],'neig','R','eigval','result','HP','AVEHP');
        end
    end
    %% check mouth exclusion
    savepath = sprintf('%s/data/midlevel/SVM/',path_project);
    files = cellstr(ls(savepath));
    %     neigs = [63 69 74 75 14 19 17 19];
    mouthex = [0 0 0 0  1 1 1 1];
    run = [1:4 1:4];
    for c = 1:8
        expr = sprintf('r0_run%d_critvar_exclmouth_%d.mat',run(c),mouthex(c));
        findfile = regexp(files,expr,'match');
        ind = find(~cellfun(@isempty,findfile));
        load([savepath files{ind}],'result');
        fprintf('Loading file %s\n',[savepath files{ind}])
        results(:,:,c) = squeeze(mean(result,2));
    end
    M = squeeze(mean(results,2));
    SE = squeeze(std(results,[],2)./sqrt(size(results,2)));
    
    % average the three test runs
    M = cat(2,M(:,1:4),mean(M(:,2:4),2),M(:,5:8),mean(M(:,6:8),2));
    SE = cat(2,SE(:,1:4),mean(SE(:,2:4),2),SE(:,5:8),mean(SE(:,6:8),2));
    
    ind = [1 5 6 10];
    ylab = {'Mouth INCL' '' 'Mouth EXCL' ''};
    for n = 1:4
        subplot(2,2,n)
        xlim([-170 215]);l=line(xlim,[.5 .5]); hold on;set(l,'Color','k','LineStyle',':');
    end
    for n = 1:4
        subplot(2,2,n)
        Project.plot_bar(-135:45:180,M(:,ind(n)),SE(:,ind(n)));
        hold on;
        ylim([.3 .7])
        set(gca,'YTick',.3:.1:.7,'XTick',[0 180],'XTickLabel',{'CS+' 'CS-'},'FontSize',14);
        box off
        axis square
        ylabel(ylab{n})
        set(gca,'YTick',[.3 .5 .7])
        xlim([-170 215])
    end
elseif strcmp(varargin{1},'SVM_getData')
    
    random = 0;
    exclmouth = 0;
    tbootstrap       = 50; %number of bootstraps
    phase            = [2 4 4 4];%baseline = 2, test = 4
    unitize_or_not    = 1;
    eigval           = [];
    trialselect      = {1:120 1:120 121:240 241:360};
    
    
    conds2include = -135:45:180;
    
    subjects = FPSA_FearGen('get_subjects');
    g = Group(subjects);
    csps = g.getcsp;
    c = 0;
    for run = 1:4 % phase 2, phase 4.1 phase 4.2 phase 4.3
        fix             = Fixmat(subjects,phase(run));%get the data
        if exclmouth == 1
            roi = fix.GetFaceROIs;
        end
        fix.unitize     = unitize_or_not;%unitize fixmaps or not
        %% get all the single trials in a huge matrix D together with labels.
        
        for ns = subjects(:)'
            for deltacsp = conds2include(:)'
                i              = ismember(fix.trialid,trialselect{run}).*(fix.subject == ns).*(fix.deltacsp == deltacsp);
                trials         = unique(fix.trialid(i == 1));
                trial_counter  = 0;
                for trialid = trials
                    trial_counter       = trial_counter + 1;
                    c      = c + 1;
                    v                   = {'subject' ns 'deltacsp' deltacsp 'trialid' trialid};
                    fix.getmaps(v);
                    if exclmouth == 1
                        fix.maps(roi(:,:,4)) = 0;
                    end
                    D(:,c)              = Vectorize(imresize(fix.maps,.1));
                    labels.sub(c)       = ns;
                    labels.run(c)       = run;
                    labels.phase(c)     = phase(run);
                    labels.trial(c)     = trial_counter;%some people have less trials check it out with plot(labels.trial)
                    labels.cond(c)      = deltacsp;
                    labels.face(c)      = csps(find(subjects==ns));
                end
            end
        end
    end
    
    savepath = sprintf('%s/data/midlevel/SVM/revision/',path_project);
    filename = sprintf('SVM_FDM_unitized%d_runs1234_N74_allconds.mat',unitize_or_not);
    save([savepath filename],'D','labels')
    
elseif strcmp(varargin{1},'SVM_getData_specunspec')
    unitize_or_not = 1;
    savepath = sprintf('%s/data/midlevel/SVM/revision/',path_project);
    filename = sprintf('SVM_FDM_unitized%d_runs1234_N74_allconds.mat',unitize_or_not);
    if exist(filename)
        load(filename);
        D0 = D;
        labels0 = labels;
    else
        FPSA_FearGen('SVM_getData');
    end
    
    CSPCSN = (ismember(labels.cond,[0 180]));
    D = D(:,CSPCSN);labels.sub = labels.sub(CSPCSN);labels.cond = labels.cond(CSPCSN);labels.phase = labels.phase(CSPCSN);labels.run = labels.run(CSPCSN);labels.face = labels.face(CSPCSN);
    filename = sprintf('SVM_FDM_unitized%d_runs1234_N74_CSPCSN.mat',unitize_or_not);
    save(filename,'D','labels');
    clear D
    clear labels
    D = D0;
    labels = labels0;
    orthconds = (ismember(labels.cond,[-90 90]));
    D = D(:,orthconds);labels.sub = labels.sub(orthconds);labels.cond = labels.cond(orthconds);labels.phase = labels.phase(orthconds);labels.run = labels.run(orthconds);labels.face = labels.face(orthconds);
    filename = sprintf('SVM_FDM_unitized%d_runs1234_N74_orthogonal.mat',unitize_or_not);
    save(filename,'D','labels');
    %this can be analysed using fpsa_decoding.py
    
elseif strcmp(varargin{1},'SVM_CSPCSN_hyperplane')
    %NEED HOLDOUT AS INPUT2
    
    %This script trains a linear SVM training CS+ vs. CS- for phases 2 and 4.
    %It collects the data and computes the eigenvalues on the
    %fly for chosen(or a range of parameters) (kernel_fwhm, number of
    %eigenvalues). As the number of trials are lower in the
    %baseline, all the test-training sessions should use the same number of
    %trials. For example to keep the comparisons comparable, in baseline 11
    %trials in the baseline, with .5 hold-out, one needs to sample the same
    %number of trials from the testphase before training.
    %the option random = 1 randomizes labels to determine the chance classification
    %performance level.
    random = 0;
    exclmouth = 0;
    tbootstrap       = 50; %number of bootstraps
    phase            = [2 4 4 4];%baseline = 2, test = 4
    holdout_ratio    = varargin{2}./100; %holdout_ratio for training vs. test set
    teig             = 100; %up to how many eigenvalues should be included for tuning SVM?
    crit             = 'var';%choose 'ellbow' classification or 'var' 90% variance explained.
    cutoffcrit       = .9;
    R                = [];%result storage for classification performance
    HP               = [];%result storage for single subject hyperplanes.
    AVEHP            = [];%result storate for average hyperplane
    
    eigval           = [];
    trialselect      = {1:120 1:120 121:240 241:360};
    conds2train      = [-90 90];%[0 180];
    
    if nargin > 2
        conds2train = varargin{3};
    end
    subjects = FPSA_FearGen('get_subjects');
    o = 0;
    for run = 1:4 % phase 2, phase 4.1 phase 4.2 phase 4.3
        o = o+1;
        fix             = Fixmat(subjects,phase(run));%get the data
        if exclmouth == 1
            roi = fix.GetFaceROIs;
        end
        fix.unitize     = 1;%unitize fixmaps or not (sum(fixmap(:))=0 or not).
        %% get all the single trials in a huge matrix D together with labels.
        global_counter = 0;
        clear D;%the giant data matrix
        clear labels;%and associated labels.
        for ns = subjects(:)'
            for deltacsp = conds2train(:)'%[0 180]%-135:45:180;
                i              = ismember(fix.trialid,trialselect{run}).*(fix.subject == ns).*(fix.deltacsp == deltacsp);
                trials         = unique(fix.trialid(i == 1));
                trial_counter  = 0;
                for trialid = trials
                    trial_counter       = trial_counter + 1;
                    global_counter      = global_counter +1;
                    c                   = global_counter;
                    v                   = {'subject' ns 'deltacsp' deltacsp 'trialid' trialid};
                    fix.getmaps(v);
                    if exclmouth == 1
                        fix.maps(roi(:,:,4)) = 0;
                    end
                    D(:,c)              = Vectorize(imresize(fix.maps,.1));
                    labels.sub(c)       = ns;
                    labels.phase(c)     = phase(run);
                    labels.trial(c)     = trial_counter;%some people have less trials check it out with plot(labels.trial)
                    labels.cond(c)      = deltacsp;
                end
            end
        end
        %% EV decomposition has to be within trainingsset already!
        ssc = 0;
        for ns = subjects(:)'
            ssc = ssc+1;
            
            this_sub = labels.sub == ns;
            DD      = D(:,this_sub);
            Ys      = labels.cond(this_sub);
            fprintf('\nRun:%d-Sub:%d-Bootstr: ',run,subjects(ssc));
            for n = 1:tbootstrap
                
                if mod(n,20)==0
                    fprintf('%d',n)
                end
                if holdout_ratio > 0
                    P       = cvpartition(Ys,'Holdout',holdout_ratio); % divide training and test datasets respecting conditions
                else
                    P.training = logical(ones(length(Ys),1));
                end
                
                %% DATA2LOAD get the eigen decomposition: D is transformed to TRIALLOAD
                %                 fprintf('starting covariance computation...')
                covmat    = cov(DD(:,P.training)');
                %                 fprintf('done\n')
                %                 fprintf('starting eigenvector computation...')
                [e dv]    = eig(covmat);
                %                 fprintf('done\n')
                dv        = sort(diag(dv),'descend');
                eigval(:,run) = dv;
                %             figure(101);
                %             plot(cumsum(dv)./sum(dv),'o-');xlim([0 200]);drawnow
                eigen     = fliplr(e);
                %collect loadings of every trial
                trialload = DD'*eigen(:,1:teig)*diag(dv(1:teig))^-.5;%dewhitened
                %% LIBSVM business
                neigs = [NaN NaN NaN NaN]; %check eigenvalues and put numbers of EV here, based on ellbow criterion.
                if strcmp(crit,'ellbow')
                    fprintf('not defined, please check visually...\n')
                    keyboard
                    neig = neigs(run);
                elseif strcmp(crit,'var')
                    neig = find(cumsum(dv)./sum(dv)>cutoffcrit,1,'first');
                end
                % take neig features from generously collected trialload
                Ycond   = double(Ys)';
                X       = trialload(:,1:neig);
                if random ==1
                    warning('Randomizing labels as wanted. \n')
                    model   = svmtrain(Shuffle(Ycond(P.training)), X(P.training,:), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
                else
                    model   = svmtrain(Ycond(P.training), X(P.training,:), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
                end
                % get the hyperplane
                try
                    w          = model.SVs'*model.sv_coef;
                    HP(:,:,ssc,n,run) = reshape(eigen(:,1:neig)*w,[50 50 1]);% old way to compute HP
                    % neg for
                    % Haufe et al ,2003
                    cov_feat   = cov(X(P.training,1:neig)); %% COV OF TRAININGS FEAT? OR ALL? cov(X(:,1:neig));
                    a                           = cov_feat*w;
                    hyper_im(:,:,ssc,n,run) = reshape(a'*eigen(:,1:neig)',50,50);
                catch
                    keyboard%sanity check: stop if something is wrong
                end
                if holdout_ratio > 0
                    [~, predicted]    = evalc('svmpredict(Ycond(P.test), X(P.test,:), model);');
                    actual = Ycond(P.test);
                    TP(ssc,n,run) = sum(predicted == 0 & actual==0);
                    FP(ssc,n,run) = sum(predicted == 0 & actual==180);
                    FN(ssc,n,run) = sum(predicted == 180 & actual==0);
                    TN(ssc,n,run) = sum(predicted == 180 & actual==180);
                    N_pred(ssc,n,run) = length(predicted);
                    
                    Precision(ssc,n,run) = TP(ssc,n,run) / (TP(ssc,n,run)+FP(ssc,n,run));
                    Recall(ssc,n,run) = TP(ssc,n,run) / (TP(ssc,n,run)+FN(ssc,n,run));
                    Accuracy(ssc,n,run) = (TP(ssc,n,run) + TN(ssc,n,run)) / (TP(ssc,n,run) + TN(ssc,n,run) + FP(ssc,n,run) + FN(ssc,n,run));
                    
                    num_eigs(ssc,n,run) = neig;
                end
            end
        end
    end
    %
    savepath = sprintf('%s/data/midlevel/SVM/revision/',path_project);
    filename = sprintf('/SVM_NEV%d_FWHM30_r%d_run%d_crit%s_exclmouth_%d_CSPCSN_HaufeHP_EVfromTrain_allruns_cond_%d_cond_%d_holdout%d_nboot_%d.mat',neig,random,run,crit,exclmouth,abs(conds2train(1)),conds2train(2),holdout_ratio*100,tbootstrap);
    try
        if holdout_ratio > 0
            save([savepath filename],'hyper_im','Precision','Accuracy','Recall','TP','FP','TN','FN','N_pred');
        else
            save([savepath filename],'hyper_im')
        end
    catch
        keyboard
    end
    
    
elseif strcmp(varargin{1},'SVM_CSPCSN_hyperplane_CSgroup')
    %This script trains a linear SVM training CS+ vs. CS- for phases 2 and 4.
    %It collects the data and computes the eigenvalues on the
    %fly for chosen(or a range of parameters) (kernel_fwhm, number of
    %eigenvalues). As the number of trials are lower in the
    %baseline, all the test-training sessions should use the same number of
    %trials. For example to keep the comparisons comparable, in baseline 11
    %trials in the baseline, with .5 hold-out, one needs to sample the same
    %number of trials from the testphase before training.
    %the option random = 1 randomizes labels to determine the chance classification
    %performance level.
    random = 0;
    exclmouth = 0;
    tbootstrap       = 100; %number of bootstraps
    phase            = [2 4 4 4];%baseline = 2, test = 4
    holdout_ratio    = varargin{2}./100; %holdout_ratio for training vs. test set
    teig             = 100; %up to how many eigenvalues should be included for tuning SVM?
    crit             = 'var';%choose 'ellbow' classification or 'var' 90% variance explained.
    cutoffcrit       = .9;
    eigval           = [];
    trialselect      = {1:120 1:120 121:240 241:360};
    
    
    subjects = FPSA_FearGen('get_subjects');
    g = Group(subjects);
    csps = g.getcsp;
    
    
    o = 0;
    for run = 1:4 % phase 2, phase 4.1 phase 4.2 phase 4.3
        o = o+1;
        fix             = Fixmat(subjects,phase(run));%get the data
        if exclmouth == 1
            roi = fix.GetFaceROIs;
        end
        fix.unitize     = 1;%unitize fixmaps or not (sum(fixmap(:))=0 or not).
        %% get all the single trials in a huge matrix D together with labels.
        global_counter = 0;
        clear D;%the giant data matrix
        clear labels;%and associated labels.
        for ns = subjects(:)'
            for deltacsp = [0 180]%-135:45:180;
                i              = ismember(fix.trialid,trialselect{run}).*(fix.subject == ns).*(fix.deltacsp == deltacsp);
                trials         = unique(fix.trialid(i == 1));
                trial_counter  = 0;
                for trialid = trials
                    trial_counter       = trial_counter + 1;
                    global_counter      = global_counter +1;
                    c                   = global_counter;
                    v                   = {'subject' ns 'deltacsp' deltacsp 'trialid' trialid};
                    fix.getmaps(v);
                    if exclmouth == 1
                        fix.maps(roi(:,:,4)) = 0;
                    end
                    D(:,c)              = Vectorize(imresize(fix.maps,.1));
                    labels.sub(c)       = ns;
                    labels.phase(c)     = phase(run);
                    labels.trial(c)     = trial_counter;%some people have less trials check it out with plot(labels.trial)
                    labels.cond(c)      = deltacsp;
                end
            end
        end
        %% EV decomposition has to be within trainingsset already!
        cs = 0;
        for csp = 1:4
            cs = cs+1;
            
            subs_face{cs} = subjects(csps==csp);
            this_face = ismember(labels.sub,subs_face{cs});
            subs_face{cs+4} = subjects(csps==csp+4);
            opp_face =  ismember(labels.sub,subs_face{cs+4});
            
            
            both_faces = logical(this_face + opp_face); %those are logicals, ok to do that.
            labels.cond(opp_face) =  abs(labels.cond(opp_face)-180); %switches 0 and 180
            
            DD      = D(:,both_faces);
            Ys      = labels.cond(both_faces);
            
            
            for n = 1:tbootstrap
                if mod(n,20)==0
                    fprintf('%d',n)
                end
                if holdout_ratio > 0
                    P       = cvpartition(Ys,'Holdout',holdout_ratio); % divide training and test datasets respecting conditions
                else
                    P.training = logical(ones(length(Ys),1));
                end
                
                %% DATA2LOAD get the eigen decomposition: D is transformed to TRIALLOAD
                %                 fprintf('starting covariance computation...')
                covmat    = cov(DD(:,P.training)');
                %                 fprintf('done\n')
                %                 fprintf('starting eigenvector computation...')
                [e dv]    = eig(covmat);
                %                 fprintf('done\n')
                dv        = sort(diag(dv),'descend');
                eigval(:,run) = dv;
                %             figure(101);
                %             plot(cumsum(dv)./sum(dv),'o-');xlim([0 200]);drawnow
                eigen     = fliplr(e);
                %collect loadings of every trial
                trialload = DD'*eigen(:,1:teig)*diag(dv(1:teig))^-.5;%dewhitened
                %% LIBSVM business
                neigs = [NaN NaN NaN NaN]; %check eigenvalues and put numbers of EV here, based on ellbow criterion.
                if strcmp(crit,'ellbow')
                    fprintf('not defined, please check visually...\n')
                    keyboard
                    neig = neigs(run);
                elseif strcmp(crit,'var')
                    neig = find(cumsum(dv)./sum(dv)>cutoffcrit,1,'first');
                end
                % take neig features from generously collected trialload
                Ycond   = double(Ys)';
                X       = trialload(:,1:neig);
                if random ==1
                    warning('Randomizing labels as wanted. \n')
                    model   = svmtrain(Shuffle(Ycond(P.training)), X(P.training,:), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
                else
                    model   = svmtrain(Ycond(P.training), X(P.training,:), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
                end
                % get the hyperplane
                try
                    w          = model.SVs'*model.sv_coef;
                    HP(:,:,cs,n,run) = reshape(eigen(:,1:neig)*w,[50 50 1]);% old way to compute HP
                    % neg for
                    % Haufe et al ,2003
                    cov_feat   = cov(X(P.training,1:neig)); %% COV OF TRAININGS FEAT? OR ALL? cov(X(:,1:neig));
                    a                           = cov_feat*w;
                    hyper_im(:,:,cs,n,run) = reshape(a'*eigen(:,1:neig)',50,50);
                catch
                    keyboard%sanity check: stop if something is wrong
                end
                if holdout_ratio >0
                    [~, predicted]    = evalc('svmpredict(Ycond(P.test), X(P.test,:), model);');
                    actual = Ycond(P.test);
                    TP(cs,n,run) = sum(predicted == 0 & actual==0);
                    FP(cs,n,run) = sum(predicted == 0 & actual==180);
                    FN(cs,n,run) = sum(predicted == 180 & actual==0);
                    TN(cs,n,run) = sum(predicted == 180 & actual==180);
                    N_pred(cs,n,run) = length(predicted);
                    
                    Precision(cs,n,run) = TP(cs,n,run) / (TP(cs,n,run)+FP(cs,n,run));
                    Recall(cs,n,run) = TP(cs,n,run) / (TP(cs,n,run)+FN(cs,n,run));
                    Accuracy(cs,n,run) = (TP(cs,n,run) + TN(cs,n,run)) / (TP(cs,n,run) + TN(cs,n,run) + FP(cs,n,run) + FN(cs,n,run));
                    
                    num_eigs(cs,n,run) = neig;
                end
            end
        end
    end
    %
    savepath = sprintf('%s/data/midlevel/SVM/revision/',path_project);
    filename = sprintf('/SVM_NEV%d_FWHM30_r%d_run%d_crit%s_exclmouth_%d_CSPCSN_HaufeHP_EVfromTrain_allruns_holdout%d_CSgroups.mat',neig,random,run,crit,exclmouth,holdout_ratio*100);
    try
        if holdout_ratio > 0
            save([savepath filename],'hyper_im','Precision','Accuracy','Recall','TP','FP','TN','FN','N_pred','HP');
        else
            save([savepath filename],'hyper_im','HP')
        end
    catch
        keyboard
    end
    
elseif strcmp(varargin{1},'SVM_CSPCSN_leave1subout')
    %This script trains a linear SVM training CS+ vs. CS- for phases 2 and 4.
    %It collects the data and computes the eigenvalues on the
    %fly for chosen(or a range of parameters) (kernel_fwhm, number of
    %eigenvalues). As the number of trials are lower in the
    %baseline, all the test-training sessions should use the same number of
    %trials. For example to keep the comparisons comparable, in baseline 11
    %trials in the baseline, with .5 hold-out, one needs to sample the same
    %number of trials from the testphase before training.
    %the option random = 1 randomizes labels to determine the chance classification
    %performance level.
    random = 1;
    exclmouth = 0;
    tbootstrap       = 100; %number of bootstraps
    phase            = [2 4 4 4];%baseline = 2, test = 4
    holdout_ratio    = .2; %holdout_ratio for training vs. test set
    teig             = 100; %up to how many eigenvalues should be included for tuning SVM?
    crit             = 'var';%choose 'ellbow' classification or 'var' 90% variance explained.
    cutoffcrit       = .9;
    R                = [];%result storage for classification performance
    HP               = [];%result storage for single subject hyperplanes.
    AVEHP            = [];%result storate for average hyperplane
    
    eigval           = [];
    trialselect      = {1:120 1:120 121:240 241:360};
    
    
    subjects = FPSA_FearGen('get_subjects');
    o = 0;
    for run = 1:4 % phase 2, phase 4.1 phase 4.2 phase 4.3
        o = o+1;
        fix             = Fixmat(subjects,phase(run));%get the data
        if exclmouth == 1
            roi = fix.GetFaceROIs;
        end
        fix.unitize     = 1;%unitize fixmaps or not (sum(fixmap(:))=0 or not).
        %% get all the single trials in a huge matrix D together with labels.
        global_counter = 0;
        clear D;%the giant data matrix
        clear labels;%and associated labels.
        for ns = subjects(:)'
            for deltacsp = [0 180]%-135:45:180;
                i              = ismember(fix.trialid,trialselect{run}).*(fix.subject == ns).*(fix.deltacsp == deltacsp);
                trials         = unique(fix.trialid(i == 1));
                trial_counter  = 0;
                for trialid = trials
                    trial_counter       = trial_counter + 1;
                    global_counter      = global_counter +1;
                    c                   = global_counter;
                    v                   = {'subject' ns 'deltacsp' deltacsp 'trialid' trialid};
                    fix.getmaps(v);
                    if exclmouth == 1
                        fix.maps(roi(:,:,4)) = 0;
                    end
                    D(:,c)              = Vectorize(imresize(fix.maps,.1));
                    labels.sub(c)       = ns;
                    labels.phase(c)     = phase(run);
                    labels.trial(c)     = trial_counter;%some people have less trials check it out with plot(labels.trial)
                    labels.cond(c)      = deltacsp;
                end
            end
        end
        %% EV decomposition has to be within trainingsset already!
        sc = 0;
        for ns = subjects(:)'
            sc = sc+1;
            
            all_other = labels.sub ~= ns;
            this_sub  = labels.sub == ns;
            DD_allbut1      = D(:,all_other);
            fprintf('\nRun: %d-leaving out sub %d.\n',run,ns);
            %             fprintf('\nRun:%d-leaving out Sub:%d-Bootstr: ',run,subjects(ns));
            %             for n = 1:tbootstrap
            %                 if mod(n,20)==0
            %                     fprintf('%d ',n)
            %                 end
            
            %                 P       = cvpartition(Ys,'Holdout',holdout_ratio); % divide training and test datasets respecting conditions
            
            %% DATA2LOAD get the eigen decomposition: D is transformed to TRIALLOAD
            %                 fprintf('starting covariance computation...')
            covmat    = cov(DD_allbut1');
            %                 fprintf('done\n')
            %                 fprintf('starting eigenvector computation...')
            [e dv]    = eig(covmat);
            %                 fprintf('done\n')
            dv        = sort(diag(dv),'descend');
            eigval(:,ns,run) = dv;
            %             figure(101);
            %             plot(cumsum(dv)./sum(dv),'o-');xlim([0 200]);drawnow
            eigen     = fliplr(e);
            %collect loadings of every trial (now the left out is
            %included again)
            trialload = D'*eigen(:,1:teig)*diag(dv(1:teig))^-.5;%dewhitened
            %% LIBSVM business
            neigs = [NaN NaN NaN NaN]; %check eigenvalues and put numbers of EV here, based on ellbow criterion.
            if strcmp(crit,'ellbow')
                fprintf('not defined, please check visually...\n')
                keyboard
                neig = neigs(run);
            elseif strcmp(crit,'var')
                neig = find(cumsum(dv)./sum(dv)>cutoffcrit,1,'first');
            end
            % take neig features from generously collected trialload
            Ycond   = double(labels.cond)';
            X       = trialload(:,1:neig);
            if random ==1
                warning('Randomizing labels as wanted. \n')
                model   = svmtrain(Shuffle(Ycond(all_other)), X(all_other,:), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
            else
                model   = svmtrain(Ycond(all_other), X(all_other,:), '-t 0 -c 1 -q'); %t 0: linear, -c 1: criterion, -q: quiet
            end
            % get the hyperplane
            try
                w          = model.SVs'*model.sv_coef;
                % Haufe et al ,2003
                cov_feat   = cov(X(all_other,1:neig)); %% COV OF TRAININGS FEAT? OR ALL? cov(X(:,1:neig));
                a          = cov_feat*w;
                hyper_im(:,:,sc,run) = reshape(a'*eigen(:,1:neig)',50,50);
            catch
                keyboard%sanity check: stop if something is wrong
            end
            [~, predicted]    = evalc('svmpredict(Ycond(this_sub), X(this_sub,:), model);');
            actual = Ycond(this_sub);
            TP(sc,run) = sum(predicted == 0 & actual==0)./length(predicted);
            FP(sc,run) = sum(predicted == 0 & actual==180)./length(predicted);
            FN(sc,run) = sum(predicted == 180 & actual==0)./length(predicted);
            TN(sc,run) = sum(predicted == 180 & actual==180)./length(predicted);
            
            Precision(sc,run) = TP(sc,run) / (TP(sc,run)+FP(sc,run));
            Recall(sc,run) = TP(sc,run) / (TP(sc,run)+FN(sc,run));
            Accuracy(sc,run) = (TP(sc,run) + TN(sc,run)) / (TP(sc,run) + TN(sc,run) + FP(sc,run) + FN(sc,run));
            
            num_eigs(sc,run) = neig;
            %             end
        end
    end
    %
    savepath = sprintf('%s/data/midlevel/SVM/revision/',path_project);
    filename = sprintf('/SVM_NEV%d_FWHM30_r%d_run%d_crit%s_exclmouth_%d_CSPCSN_HaufeHP_leave1out_EVfromTrain.mat',neig,random,run,crit,exclmouth);
    save([savepath filename],'hyper_im','Precision','Accuracy','Recall','FP','TP','FN','TN');
    
elseif strcmp(varargin{1},'get_trials_for_svm_idiosync')
    % here we classify subjects to show their idiosyncratic patterns.
    % we classify them within each phase seperately to account for diff.
    % number of trials, i.e. baseline, test1,test2,test3
    r             = 0; % for label randomization check
    name_analysis = 'subjects_inphase'; %classify subjects, respect phases
    savepath      = fullfile(path_project,['data\midlevel\SVM_idiosyncrasy\']);
    filename      = 'trialdata.mat';
    savedfile     = [savepath filename];
    %   savepath      = fullfile(path_project,['data\midlevel\SVM_idiosyncrasy_' name_analysis '_rand' num2str(r) '.mat']);
    if nargin >1
        force = varargin{2};
    end
    
    if ~exist(savepath)
        mkdir(savepath)
    end
    
    if ~exist(savedfile) || force==1
        if ~exist(savedfile)
            fprintf('Trial data not yet found at %s, \ncollecting it now. \n',savepath)
            WaitSecs(2); %make it readable.
        elseif force == 1
            fprintf('Forced to compute this file anew: \n %s',savepath)
            WaitSecs(2); %make it readable.
        end
        
        scale         = .1;
        run2ph        = [2 4 4 4];
        run2trial     = {1:120 1:120 121:240 241:360};
        subs          = FPSA_FearGen('get_subjects');
        nsubs         = length(subs);
        
        cutoffcrit     = .9; %percentage of variance that should be explained.
        
        fprintf('Started analysis (%s): %s\n',datestr(now,'hh:mm:ss'),name_analysis);
        
        ttrial           = nsubs*length(cell2mat(run2trial));
        D                = NaN(2500,ttrial);
        labels.sub       = NaN(1,ttrial);
        labels.run       = NaN(1,ttrial);
        labels.trial     = NaN(1,ttrial);
        labels.cond      = NaN(1,ttrial);
        v = [];
        c = 0;
        for sub = subs(:)'
            for run = 1:4
                fix = Fixmat(sub,run2ph(run));
                for tr = run2trial{run}
                    v = {'subject' sub, 'trialid' tr 'deltacsp' fix.realcond};
                    fprintf('Subject %d run %d trial %d\n',sub,run,tr);
                    fix.getmaps(v);
                    if ~any(isnan(fix.maps(:)))
                        c                   = c+1;
                        %scale it if necessary
                        if scale ~= 1
                            fix.maps        = imresize(fix.maps,scale,'method','bilinear');
                        end
                        D(:,c)              = fix.vectorize_maps;
                        labels.sub(c)       = sub;
                        labels.run(c)       = run;
                        labels.trial(c)     = tr;
                        labels.cond(c)      = unique(fix.deltacsp(fix.selection));
                    end
                end
            end
        end
        
        %cut the nans
        todelete = isnan(labels.sub); %could be derived from labels.anything, means empty fixmap
        fprintf('Will delete %g trials...\n',sum(todelete));
        D(:,todelete)=[];
        labels.sub(:,todelete)=[];
        labels.run(:,todelete)=[];
        labels.trial(:,todelete)=[];
        labels.cond(:,todelete)=[];
        
        c = 0;
        for l = unique(labels.sub)
            c = c + 1;
            labels.easy_sub(labels.sub == l) = c;
        end
        
        %% DATA2LOAD get the eigen decomposition: D is transformed to TRIALLOAD
        fprintf('starting covariance computation\n')
        covmat    = cov(D');
        fprintf('done\n')
        fprintf('starting eigenvector computation\n')
        [e dv]    = eig(covmat);
        fprintf('done\n')
        dv        = sort(diag(dv),'descend');
        eigval(:,run) = dv;
        %     figure(100);
        %     plot(cumsum(dv)./sum(dv),'o-');xlim([0 200]);drawnow
        eigen     = fliplr(e);
        neig = find(cumsum(dv)./sum(dv)>cutoffcrit,1,'first');
        
        fprintf('%002d Eigenvectors explain 90% of variance. \n',neig)
        
        %collect loadings of every trial
        trialload = D'*eigen(:,1:neig)*diag(dv(1:neig))^-.5;%dewhitened
        
        
        save(savedfile)
    else
        load(savedfile);
        fprintf('Was already saved, loading it from \n%s\n',savedfile)
        Ndim = size(trialload);
        fprintf('Found a Matrix of dim = %03d (trials) x %03d (EV loadings).\n',Ndim(1),Ndim(2))
        fprintf('Labels show that we have %02d subjects, which are the following:\n',length(unique(labels.sub)));
        unique(labels.sub)
        WaitSecs(1); %make it readable.
    end
    varargout{1} = trialload;
    varargout{2} = labels;
    
elseif strcmp(varargin{1},'svm_howmanytrialspersub')
    
    [~,labels] = FPSA_FearGen('get_trials_for_svm_idiosync');
    for run = 1:4
        ind = labels.run == run;
        ntrials(:,run)    = histc(labels.easy_sub(ind),unique(labels.easy_sub));
    end
    disp([unique(labels.easy_sub)' ntrials])
    
    fprintf('Minimum number of trials is (run 1 2 3 4):\n')
    [minN, minisub] = min(ntrials);
    disp(minN)
    
    fprintf('This should be fed into SVM classifying subjects to make it fairer.\n')
    
    
    varargout{1} = minN;
    
elseif strcmp(varargin{1},'svm_classify_subs_1vs1')
    
    nbootstrap = 1000;
    randomize  = 0;
    PHoldout    = .2;
    
    savepath      = fullfile(path_project,'data\midlevel\SVM_idiosyncrasy\');
    filename      = sprintf('performance_1vs1_r%d.mat',randomize);
    savedfile     = [savepath filename];
    %   savepath      = fullfile(path_project,['data\midlevel\SVM_idiosyncrasy_' name_analysis '_rand' num2str(r) '.mat']);
    if nargin > 1
        force = varargin{2};
    end
    
    if ~exist(savepath)
        mkdir(savepath)
    end
    
    if ~exist(savedfile) || force==1
        
        if ~exist(savedfile)
            fprintf('Trial data not yet found at %s, \ncollecting it now. \n',savepath)
            WaitSecs(2); %make it readable.
        elseif force == 1
            fprintf('Forced to compute this file anew: \n %s',savepath)
            WaitSecs(2); %make it readable.
        end
        
        [data,labels] = FPSA_FearGen('get_trials_for_svm_idiosync');
        nsub = max(unique(labels.easy_sub));
        ntrialspersub = FPSA_FearGen('svm_howmanytrialspersub');
        
        
        for run = 1:4
            runind = labels.run == run;
            for s1 = 1:nsub
                for s2 = 1:nsub
                    if s1 < s2;
                        fprintf('Run: %02d. Classifying sub %02d vs %02d.\n',run,s1,s2)
                        for n = 1:nbootstrap
                            select    = logical(ismember(labels.easy_sub,[s1 s2]).*runind);
                            Y         = labels.easy_sub(select)';
                            X         = data(select,:);
                            Y1        = randsample(find(Y == s1),ntrialspersub(run));
                            Y2        = randsample(find(Y == s2),ntrialspersub(run));
                            Y         = Y([Y1;Y2]);
                            X         = X([Y1;Y2],:);
                            if randomize == 1
                                Y = Shuffle(Y);
                            end
                            
                            P         = cvpartition(Y,'Holdout',PHoldout); %prepares trainings vs testset
                            cmq     = sprintf('-t 0 -c 1 -q');
                            ind     = logical(P.training);
                            model   = svmtrain(Y(ind), X(ind,:), cmq);
                            ind     = logical(P.test);
                            [~,predicted]               = evalc('svmpredict(Y(ind), X(ind,:), model);');%doing it like this supresses outputs.
                            %                         confmats(:,:,n)   = confusionmat(Y(ind),predicted,'order',[s1 s2]);
                            result(n)         = sum(Y(ind)==predicted)./length(predicted);
                        end
                        performance(s1,s2,run,:) = result;
                        result = [];
                    end
                end
            end
        end
        save(savedfile,'performance','nsub')
    else
        load(savedfile)
        fprintf('Was already saved, loading it from \n%s\n',savedfile)
    end
    
    varargout{1} = performance;
    nsub = size(performance,2);
    keyboard
    av_perf = mean(performance,3);
    av_perf = [av_perf;zeros(1,nsub)];
    perf = av_perf(logical(triu(ones(nsub,nsub))));
    
    average_performance = mean(perf);
    std_average_performance     = std(perf);
    
elseif strcmp(varargin{1},'svm_classify_subs_1vsrest')
    
    
    nbootstrap = 1000;
    randomize  = 0;
    PHoldout    = .2;
    
    
    savepath      = fullfile(path_project,'data\midlevel\SVM_idiosyncrasy\');
    filename      = sprintf('performance_1vsrest_r%d.mat',randomize);
    savedfile     = [savepath filename];
    %   savepath      = fullfile(path_project,['data\midlevel\SVM_idiosyncrasy_' name_analysis '_rand' num2str(r) '.mat']);
    if nargin > 1
        force = varargin{2};
    end
    
    if ~exist(savepath)
        mkdir(savepath)
    end
    
    if ~exist(savedfile) || force==1
        
        if ~exist(savedfile)
            fprintf('Trial data not yet found at %s, \ncollecting it now. \n',savepath)
            WaitSecs(2); %make it readable.
        elseif force == 1
            fprintf('Forced to compute this file anew: \n %s',savepath)
            WaitSecs(2); %make it readable.
        end
        
        [data,labels] = FPSA_FearGen('get_trials_for_svm_idiosync');
        nsub = max(unique(labels.easy_sub));
        performance = [];
        
        for run = 1:4
            fprintf('Starting 1vsrest classification for run = %d.\n',run)
            
            fprintf('Bootstrap count: N = 0... ')
            for n = 1:nbootstrap
                if mod(n,200) == 0
                    fprintf('%03d... ',n)
                end
                
                select    = logical(labels.run == run);
                Y         = labels.easy_sub(select)';
                X         = data(select,:);
                if randomize == 1
                    Y = Shuffle(Y);
                end
                
                P       = cvpartition(Y,'Holdout',PHoldout); %prepares trainings vs testset
                cmq     = sprintf('-t 0 -c 1 -q');
                ind     = logical(P.training);
                model   = ovrtrain(Y(ind), X(ind,:), cmq);
                ind     = logical(P.test);
                [~,predicted]               = evalc('ovrpredict(Y(ind), X(ind,:), model);');%doing it like this supresses outputs.
                
                confmats(:,:,run,n)   = confusionmat(Y(ind),predicted,'order',unique(labels.easy_sub));
                result(n)         = sum(Y(ind)==predicted)./length(predicted);
            end
            fprintf('\n')
            performance(run,:) = result;
        end
        save(savedfile,'confmats','performance','nsub')
    else
        load(savedfile)
        fprintf('Was already saved, loading it from \n%s\n',savedfile)
    end
    
    varargout{1} = performance;
    varargout{2} = confmats;
    
elseif strcmp(varargin{1},'old_SFig_03')
    %% plot
    savepath = sprintf('%s/data/midlevel/SVM/',path_project);
    files = cellstr(ls(savepath));
    %     neigs = [63 69 74 75 14 19 17 19];
    crit = {'ellbow','ellbow','ellbow','ellbow','var','var','var','var'};
    run = [1:4 1:4];
    for c = 1:8
        expr = sprintf('r0_run%d_crit%s_exclmouth_0.mat',run(c),crit{c});
        findfile = regexp(files,expr,'match');
        ind = find(~cellfun(@isempty,findfile));
        load([savepath files{ind}],'result');
        results(:,:,c) = squeeze(mean(result,2));
    end
    
    M = squeeze(mean(results,2));
    SE = squeeze(std(results,[],2)./sqrt(size(results,2)));
    
    % average the three test runs
    M = cat(2,M(:,1:4),mean(M(:,2:4),2),M(:,5:8),mean(M(:,6:8),2));
    SE = cat(2,SE(:,1:4),mean(SE(:,2:4),2),SE(:,5:8),mean(SE(:,6:8),2));
    
    
    figure(1001)
    clf
    for n = 1:10;subplot(2,5,n);xlim([-170 215]);l=line(xlim,[.5 .5]); hold on;set(l,'Color','k','LineStyle',':');end
    hold on
    labels = {'Baseline' 'Test_1' 'Test_2' 'Test_3' 'Test_M' };
    for n = 1:10
        subplot(2,5,n);
        Project.plot_bar(-135:45:180,M(:,n));
        hold on;
        errorbar(-135:45:180,M(:,n),SE(:,n),'k.','LineWidth',2)
        ylim([.3 .7])
        set(gca,'YTick',.3:.1:.7,'XTick',[0 180],'XTickLabel',{'CS+' 'CS-'},'FontSize',14);
        box off
        axis square
        if ismember(n,[1 6])
            ylabel('Classified as CS+')
        end
        set(gca,'YTick',[.3 .5 .7])
        xlim([-170 215])
        if n<6
            title(labels{n})
        end
    end
    %% partial figure for figure_04
    figure(1002)
    clf
    for n = 1:3;subplot(1,3,n);xlim([-170 215]);l=line(xlim,[.5 .5]); hold on;set(l,'linewidth',1.5,'Color','k','LineStyle',':');end % so the lines are behind bars
    hold on
    labels = {'Baseline' 'Test' 'Test'};
    spc = 0;
    for n = [6 10]
        spc = spc + 1;
        subplot(1,3,spc);
        Project.plot_bar(-135:45:180,M(:,n));
        e = errorbar(-135:45:180,M(:,n),SE(:,n),'k.');
        set(e,'LineWidth',2,'Color','k')
        hold on;
        ylim([.3 .7])
        set(gca,'YTick',.3:.1:.7,'XTick',[0 180],'XTickLabel',{'CS+' 'CS-'},'FontSize',14);
        box off
        axis square
        ylabel('Classified as CS+')
        set(gca,'YTick',[.3 .5 .7])
        xlim([-170 215])
        title(labels{spc})
    end
    subplot(1,3,3)
    clear results
    savepath = sprintf('%s/data/midlevel/SVM/',path_project);
    files = cellstr(ls(savepath));
    %     neigs = [63 69 74 75 14 19 17 19];
    crit = {'var','var','var','var'};
    for c = 1:4
        expr = sprintf('r0_run%d_crit%s_exclmouth_1.mat',c,crit{c});
        findfile = regexp(files,expr,'match');
        ind = find(~cellfun(@isempty,findfile));
        load([savepath files{ind}],'result');
        results(:,:,c) = squeeze(mean(result,2));
    end
    
    M = squeeze(mean(results,2));
    SE = squeeze(std(results,[],2)./sqrt(size(results,2)));
    M = mean(M(:,2:4),2);
    SE = mean(SE(:,2:4),2);
    Project.plot_bar(-135:45:180,M);
    hold on
    e = errorbar(-135:45:180,M,SE,'k.');
    set(e,'LineWidth',2,'Color','k')
    ylim([.3 .7])
    set(gca,'YTick',.3:.1:.7,'XTick',[0 180],'XTickLabel',{'CS+' 'CS-'},'FontSize',14);
    box off
    axis square
    ylabel('Classified as CS+')
    set(gca,'YTick',[.3 .5 .7])
    xlim([-170 215])
    title(labels{spc})
    
    for n = 1:3
        subplot(1,3,n);
        set(gca,'LineWidth',1.5,'FontSize',16)
        
    end
    
elseif strcmp(varargin{1},'figure_01A');
    %% this is the figure of faces, FDMs and dissimilarity matrices
    % get V1 dissimilarity
    p = Project;
    path2v1 = [strrep(p.path_project,'data','stimuli') 'V1\V1_*'];
    dummy           = dir([path2v1 '*.mat']);
    v1files         = [repmat([fileparts(path2v1) filesep],length(dummy),1) vertcat(dummy(:).name)];
    tfiles          = size(v1files,1);
    im0              = [];
    im               = [];
    c =0;
    for i = 1:tfiles
        c = c+1;
        dummy       = load(v1files(i,:));
        im0(:,:,c)   = dummy.v1;
    end
    im = im0  - repmat(mean(im0,3),[1 1 8]); % mean correction
    dissv1 = 1-corr(reshape(im,[400*400,8])); %dissimilarity v1
    
    figure(1)
    subplot(2,1,1)
    dissv1 = CancelDiagonals(dissv1,NaN);
    [d u]   = GetColorMapLimits(dissv1,2.5);
    imagesc(dissv1,[0 1.8]);
    axis square;c = colorbar;
    set(c,'Ytick',caxis)
    set(gca,'fontsize',15);
    axis off
    
    %chose exemplary subject
    %     figure;
    %     subs = FPSA_FearGen('get_subjects');
    %     sim = FPSA_FearGen('get_rsa',1:100);
    %     for n = 1:61;
    %         subplot(8,8,n);
    %         dissmatz = squareform(sim.correlation(n,:));
    %         dissmatz = CancelDiagonals(dissmatz,0);
    %         dissmatz = dissmatz(9:end,9:end);
    %         [d u]   = GetColorMapLimits(dissmatz,2.5);
    %         imagesc(dissmatz,[0 2]);
    %             axis square;
    %     end
    
    
    exemplsub = 45;
    
    
    subplot(2,1,2);
    subs = FPSA_FearGen('get_subjects');
    mat = FPSA_FearGen('get_fpsa_fair',{'fix',1:100},1:3);
    dissmat = squareform(mat.correlation(subs==exemplsub,:)); %get_rsa uses pdist, which is 1-r already, so no 1-squareform necessary.
    dissmat = dissmat(9:end,9:end);
    dissmat = CancelDiagonals(dissmat,NaN);
    %     [d2 u2]   = GetColorMapLimits(dissmat,2.5);
    imagesc(dissmat,[0 1.8]);
    axis square;c = colorbar;
    set(c,'Ytick',caxis)
    set(gca,'fontsize',15);
    axis off;
    
    
    fix = Fixmat(exemplsub,4);
    s   = Subject(exemplsub);
    figure(exemplsub);
    fix.contourplot(4,[.2 .3 .4 .5 .6]);
    colors        = GetFearGenColors;
    
    colors        = circshift(colors(1:8,:),s.csp-4); %need to resort them so that csp is red. (check again)
    
    for n = 1:8
        subplot(3,3,n);
        h = gca;
        x = xlim;
        y = ylim;
        rectangle('position',[x(1) y(1) diff(xlim) diff(ylim)],'edgecolor',colors(n,:),'linewidth',7);
    end
elseif strcmp(varargin{1},'figure_01BCDE'); %figure_01B %figure_01C %figure_01D %figure_01E
    %% this is the cartoon figure where hypotheses are presented;
    figure;
    set(gcf,'position',[1958         247        1443         740]);
    %few fun definition to write axis labels
    small_texth = @(h) evalc('h = text(4,9,''CS+'');set(h,''HorizontalAlignment'',''center'',''fontsize'',6);h = text(8,9,''CS-'');set(h,''HorizontalAlignment'',''center'',''fontsize'',6);hold on;plot([4 4],[ylim],''k--'',''color'',[0 0 0 .4]);plot([xlim],[4 4],''k--'',''color'',[0 0 0 .4])');
    small_textv = @(h) evalc('h = text(.5,4,''CS+'');set(h,''HorizontalAlignment'',''right'',''fontsize'',6);h = text(.5,8,''CS-'');set(h,''HorizontalAlignment'',''right'',''fontsize'',6);');
    params = {{[.5 .5] 0} {[4.5 4.5] 0} {[4.5 2.5] 0} {[4.5 4.5] 4.5}};
    titles = {sprintf('Perceptual\nBaseline') sprintf('Perceptual\nExpansion') sprintf('Adversity\nGradient') sprintf('CS+\nAttraction')};
    width  = 2.3;
    d      = [-.8 -20 -20 -20];
    u      = [ .8  20  20  20];
    %
    spi = {[1 2 13 14] 25 26 [37 38 49 50]};
    for ncol = 1:4
        
        [model w] = getcorrmat(params{ncol}{1},params{ncol}{2},0,1,width);
        model     = 1-corrcov(model);
        
        % ori   = mdscale(1-model,2,'Criterion','strain','start','cmdscale','options',statset('display','final','tolfun',10^-12,'tolx',10^-12));
        colors    = GetFearGenColors;
        colors    = [colors(1:8,:);colors(1:8,:)];
        %
        [y]       = mdscale(model,2,'Criterion',criterion,'start','cmdscale','options',statset('display','final','tolfun',10^-12,'tolx',10^-12));
        if y(4,1) < 0%simply make all red node located at the same position on the figure;
            y = circshift(y,[4,0]);
        end
        % % row 1
        subplot(6,12,spi{1}+(ncol-1)*3);
        plot(y([1:8 1],1),y([1:8 1],2),'.-.','linewidth',2,'color',[0.6 0.6 0.6]);
        hold on;
        for nface = 1:8
            plot(y(nface,1),y(nface,2),'.','color',colors(nface,:),'markersize',50,'markerface',colors(nface,:));
        end
        hold off;
        xlim([-1 1]);
        ylim([-1 1]);
        axis square;axis off
        title(titles{ncol},'fontweight','normal','horizontalalignment','center','verticalalignment','middle','fontsize',15);
        if ncol == 1
            text(-1.7,max(ylim)/2-.4,sprintf('MDS'),'fontsize',12,'rotation',90,'horizontalalignment','center');
        end
        
        % row 2
        if ncol < 4
            subplot(6,12,spi{2}+(ncol-1)*3);
            imagesc(-w(1,:)'*w(1,:),[d(ncol) u(ncol)]);
            axis off;axis square;
            try
                small_texth();small_textv();
            end
            if ncol == 1
                text(-6.5,max(ylim)/2,sprintf('Covariance\nComponents'),'fontsize',12,'rotation',90,'horizontalalignment','center');
            end
            
            subplot(6,12,spi{3}+(ncol-1)*3);
            imagesc(-w(2,:)'*w(2,:),[d(ncol) u(ncol)]);
            axis off;axis square;
            try
                small_texth();
            end
        else
            subplot(6,12,spi{2}+(ncol-1)*3);
            imagesc(-w(1:2,:)'*w(1:2,:),[d(ncol) u(ncol)]);
            axis off;axis square;
            try
                small_texth();small_textv();
            end
            subplot(6,12,spi{3}+(ncol-1)*3);
            imagesc(-w(3,:)'*w(3,:),[d(ncol) u(ncol)]);
            axis off;axis square;
            try
                small_texth();
            end
        end
        
        %last row
        subplot(6,12,spi{4}+(ncol-1)*3);
        %
        % row 3
        
        axis square
        imagesc(model,[.1 2]);
        if ncol == 1
            pos = get(gca,'position');
            hc  = colorbar('eastoutside');
            set(gca,'position',pos);
            try
                hc.Position(3:4) = hc.Position(3:4)./2;
                set(hc,'Ticks',[0.1 2],'TickLabels',[0 2],'box','off');
            end
        end
        %
        %         imagesc(model);colorbar
        axis off;
        axis square;
        h = text(.5,4,'CS+');set(h,'HorizontalAlignment','right','fontsize',10);
        h = text(.5,8,'CS-');set(h,'HorizontalAlignment','right','fontsize',10);
        h = text(.5,2,sprintf('90%c',char(176)));set(h,'HorizontalAlignment','right','fontsize',6);
        h = text(.5,6,sprintf('-90%c',char(176)));set(h,'HorizontalAlignment','right','fontsize',6);
        
        h = text(4,9,'CS+');set(h,'HorizontalAlignment','center','fontsize',10);
        h = text(8,9,'CS-');set(h,'HorizontalAlignment','center','fontsize',10);
        h = text(2,9,sprintf('90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',6);
        h = text(6,9,sprintf('-90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',6);
        
        if ncol == 1
            text(-2.5,max(ylim)/2,sprintf('Theoretical\nSimilarity\Matrices'),'fontsize',12,'rotation',90,'horizontalalignment','center');
        end
        
        %         set(gca,'xtick',[4 8],'xticklabel',{'CS+' 'CS-'},'yticklabel','')
    end
    
    %     SaveFigure(sprintf('%sdata/midlevel/figures/figure_01B.png',path_project),'-r300');
    
elseif strcmp(varargin{1},'figure_02B')
    %% Barplots results for SCR, Ratings, ROI fixation counts.
    % general layout business.
    fs       = 11; %fontsize
    ms       = 18;  %markersize
    sps      = [5 4]; %subplotsize rows x columns
    flw      = 2; %fitline width
    scatmark = 's';
    scatcol1 = repmat(.5,1,3);%repmat(.8,1,3)
    mbc      = [.7 0 0]; %mean bar color for scatterplots
    web      = 1; %width errorbars
    colors   = [repmat(0.3,3,3)];
    grayshade= [.5 .5 .5];
    alpha_gf = .001;
    
    figure(1002);
    clf;
    h = gcf;
    h.Position = [806          58         793        1036];
    %% old figure 02 from here
    force_scr      = 0;
    force_scrfit   = 0;
    force_rate     = 0;
    force_ratefit  = 0;
    p              = Project;
    subs           = FPSA_FearGen('get_subjects');
    scrsubs        = subs(ismember(subs,p.subjects(p.subjects_scr)));
    scrpath        = sprintf('%sdata/midlevel/SCR_N%d.mat',path_project,length(scrsubs));
    %% SCR
    if ~exist(scrpath)||force_scr == 1
        g        = Group(scrsubs);
        out      = g.getSCR(2.5:5.5);
        save(scrpath,'out');
        clear g
    else
        load(scrpath)
    end
    av       = mean(out.y);
    sem      = std(out.y)./sqrt(length(scrsubs));
    %fit baseline to see if there's tuning
    data.y   = out.y(:,1:8);
    data.x   = repmat(-135:45:180,[length(scrsubs) 1])';
    data.ids = NaN;
    base     = Tuning(data);
    base.GroupFit(3);
    %same for test (cond not possible)
    data.y   = out.y(:,19:26);
    data.x   = repmat(-135:45:180,[length(scrsubs) 1]);
    data.ids = NaN;
    test     = Tuning(data);
    test.GroupFit(3);
    params   = test.groupfit.Est;
    %     params(3)= deg2rad(params(3)); %for VonMises Fit
    
    nulltrials = out.y(:,[9 18 27]);
    
    CI = 1.96*std(nulltrials)./sqrt(length(nulltrials)); %2times because in two directions (MEAN plusminus) % this is for plotting nulltrial CI later
    
    %are SCRS CS+ vs CS- sign. different?
    [h,pval(2),ci,teststat] = ttest(out.y(:,13),out.y(:,17))
    [h,pval(3),ci,teststat] = ttest(out.y(:,22),out.y(:,26))
    % get the numbers for the text
    differ = (out.y(:,13)-out.y(:,17))./out.y(:,17);
    mean(differ)
    std(differ)
    
    % single subject fits for parameter plot
    path_scrampl = sprintf('%sdata/midlevel/SCR_N%d_fits.mat',path_project,length(scrsubs));
    
    if ~exist(path_scrampl)||force_scrfit ==1
        scr_ampl = nan(length(scrsubs),4);
        scr_pval = nan(length(scrsubs),4);
        sc = 0;
        for sub = scrsubs(:)'
            sc = sc+1;
            for ph = [2 4]
                s = Subject(sub);
                s.get_fit('scr',ph)
                scr_ampl(sc,ph) = s.get_fit('scr',ph).params(1);
                scr_pval(sc,ph) = s.get_fit('scr',ph).pval;
                save(path_scrampl,'scr_ampl','scr_pval');
            end
        end
    else
        load(path_scrampl)
    end
    
    %% plot SCR
    %baseline
    subplot(sps(1),sps(2),5);
    pa = patch([-180 225 225 -180],[mean(nulltrials(:,1))-CI(1) mean(nulltrials(:,1))-CI(1) mean(nulltrials(:,1))+CI(1) mean(nulltrials(:,1))+CI(1)],'r','EdgeColor','none');
    set(pa,'FaceAlpha',.5,'FaceColor',grayshade,'EdgeColor','none');
    hold on;
    Project.plot_bar(-135:45:180,av(1:8));
    hold on;
    try
        errorbar(-135:45:180,av(1:8),sem(1:8),'ok','LineWidth',web,'marker','none','capsize',0);
    catch
        errorbar(-135:45:180,av(1:8),sem(1:8),'ok','LineWidth',web,'marker','none');
    end
    if base.groupfit.pval > -log10(alpha_gf)
        plot(base.groupfit.x_HD,base.groupfit.fit_HD,'Color',[0 0 0],'LineWidth',flw)
    else
        line([-150 195],repmat(mean(av(1:8)),[1 2]),'Color',[0 0 0],'LineWidth',flw)
    end
    ylabel(sprintf('SCR\n(z-score)'),'fontsize',fs)
    axis square;axis tight;box off
    Publication_Ylim(gca,0,1);
    Publication_NiceTicks(gca,1);
    Publication_RemoveXaxis(gca);
    set(gca,'xlim',[-155 200],'xticklabel',[]);
    %% plot SCR (Cond)
    subplot(sps(1),sps(2),6);
    pa = patch([-180 225 225 -180],[mean(nulltrials(:,2))-CI(2) mean(nulltrials(:,2))-CI(2) mean(nulltrials(:,2))+CI(2) mean(nulltrials(:,2))+CI(2)],'r','EdgeColor','none');
    set(pa,'FaceAlpha',.5,'FaceColor',grayshade,'EdgeColor','none')
    hold on;
    Project.plot_bar(-135:45:180,av(10:17));axis square;box off;hold on;
    try
        errorbar(-135:45:180,av(10:17),sem(10:17),'ok','LineWidth',web,'marker','none','capsize',0);
    catch
        errorbar(-135:45:180,av(10:17),sem(10:17),'ok','LineWidth',web,'marker','none');
    end
    axis square;axis tight;
    Publication_Ylim(gca,0,1);
    Publication_NiceTicks(gca,1)
    Publication_RemoveXaxis(gca);
    set(gca,'xlim',[-155 200],'xticklabel',[]);
    
    line([0 180],repmat(max(ylim),1,2),'Color',[0 0 0])
    if pval(2) < .001
        text(90,max(ylim)+range(ylim)*.04,'***','HorizontalAlignment','center','fontsize',16);
    elseif pval(2) < .01
        text(90,max(ylim)+range(ylim)*.04,'**','HorizontalAlignment','center','fontsize',16);
    elseif pval(2) < .05
        text(90,max(ylim)+range(ylim)*.04,'*','HorizontalAlignment','center','fontsize',16);
    end
    
    
    %% plot SCR (test)
    subplot(sps(1),sps(2),7);
    pa = patch([-180 225 225 -180],[mean(nulltrials(:,3))-CI(3) mean(nulltrials(:,3))-CI(3) mean(nulltrials(:,3))+CI(3) mean(nulltrials(:,3))+CI(3)],'r','EdgeColor','none');
    set(pa,'FaceAlpha',.5,'FaceColor',grayshade,'EdgeColor','none')
    hold on;
    Project.plot_bar(-135:45:180,av(19:26));axis square;box off;hold on;
    try
        errorbar(-135:45:180,av(19:26),sem(19:26),'ok','LineWidth',web,'marker','none','capsize',0);
    catch
        errorbar(-135:45:180,av(19:26),sem(19:26),'ok','LineWidth',web,'marker','none');
    end
    x = -150:0.1:195;
    if test.groupfit.pval > -log10(alpha_gf)
        plot(test.groupfit.x_HD,test.groupfit.fit_HD,'Color',[0 0 0],'LineWidth',flw)
    else
        line([-150 195],repmat(mean(av(1:8)),[1 2]),'Color',[0 0 0],'LineWidth',flw)
    end
    axis square;axis tight;
    Publication_Ylim(gca,0,1);
    Publication_NiceTicks(gca,1)
    Publication_RemoveXaxis(gca);
    set(gca,'xlim',[-155 200],'xticklabel',[]);
    %% scatter plot of single subject SCR amplitude params
    subplot(sps(1),sps(2),8)
    hold off;
    mat = scr_ampl(:,[2 3 4]);
    dotplot(mat);
    axis square;set(gca,'xticklabel',[]);
    Publication_Ylim(gca,0,1);
    Publication_NiceTicks(gca,1);
    Publication_RemoveXaxis(gca);
    %     %paired ttest asterix b-t
    line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
    %are amplitudes alpha diff from base to test?
    [h,pval,ci,teststat] = ttest(scr_ampl(:,2),scr_ampl(:,4))
    if pval < .001
        text(3,max(ylim)+range(ylim)*.04,'***','HorizontalAlignment','center','fontsize',16);
    elseif pval < .01
        text(3,max(ylim)+range(ylim)*.04,'**','HorizontalAlignment','center','fontsize',16);
    elseif pval < .05
        text(3,max(ylim)+range(ylim)*.04,'*','HorizontalAlignment','center','fontsize',16);
    end
    %     Publication_Asterisks(mat,1:2:5);
    
    %% plot ratings
    subs              = FPSA_FearGen('get_subjects');
    ratepath           = sprintf('%sdata/midlevel/Ratings_N%d.mat',path_project,length(subs));
    %
    if ~exist(ratepath)||force_rate == 1
        g                 = Group(subs);
        ratings           = g.getRatings(2:4);
        save(ratepath,'ratings');
        clear g
    else
        load(ratepath)
    end
    %demean per phase
    
    % check all three phases for tuning
    for ph = 1:3
        ratings(:,:,ph) = ratings(:,:,ph);
        data.y   = ratings(:,:,ph);
        data.x   = repmat(-135:45:180,[length(subs) 1]);
        data.ids = subs;
        t     = Tuning(data);
        t.GroupFit(3);
        fit(ph) = t.groupfit;
    end
    % get single sub Gaussian ampl
    path_rateampl = sprintf('%sdata/midlevel/Ratings_N%d_fits.mat',path_project,length(subs));
    
    if ~exist(path_rateampl)||force_ratefit ==1
        for ph = 1:3
            sc = 0;
            for sub = subs(:)'
                sc = sc+1;
                s = Subject(sub);
                s.fit_method = 3;
                rate_ampl(sc,ph) = s.get_fit('rating',ph+1).params(1);
                rate_pval(sc,ph) = s.get_fit('rating',ph+1).pval;
                save(path_rateampl,'rate_ampl','rate_pval');
            end
        end
    else
        load(path_rateampl)
    end
    
    %% RATINGS GROUP DATA
    tits = {'Baseline' 'Conditioning' 'Generalization'};
    for n = [2 3 1]
        sp = n;
        subplot(sps(1),sps(2),sp)
        hold off
        Project.plot_bar(-135:45:180,mean(ratings(:,:,n)));
        hold on;
        try
            e        = errorbar(-135:45:180,mean(ratings(:,:,n)),std(ratings(:,:,n))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none','capsize',0);
        catch
            e        = errorbar(-135:45:180,mean(ratings(:,:,n)),std(ratings(:,:,n))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none');
        end
        set(e,'LineWidth',web,'Color','k')
        hold on;
        axis square;axis tight;
        box off
        if n == 1
            ylabel(sprintf('Shock\nExpectancy'),'fontsize',fs)
        end
        %Gaussian Fits
        hold on;
        if fit(n).pval > -log10(alpha_gf)
            plot(fit(n).x_HD,fit(n).fit_HD,'Color',[0 0 0],'LineWidth',flw)%add Groupfit line
        else
            l = line([-150 195],repmat(mean(mean(ratings(:,:,n))),[1 2]),'Color','k','LineWidth',2);
        end
        %         Publication_Ylim(gca,0,2)
        ylim([0 8])
        Publication_NiceTicks(gca,1)
        Publication_RemoveXaxis(gca);
        set(gca,'xticklabel',[]);
        title(tits{n},'Position',[min(xlim)+range(xlim)/2 max(ylim)+range(ylim)*.2],'horizontalalignment','center')
    end
    %% RATINGS SINGLE SUBJECT DATA
    subplot(sps(1),sps(2),4);
    mat = rate_ampl(:,[1 2 3]);
    dotplot(mat);
    axis square;set(gca,'xticklabel',[]);
    Publication_Ylim(gca,0,1);
    Publication_NiceTicks(gca,1);
    %     Publication_Asterisks(mat,1:2:5);
    tt  = title(sprintf('Tuning\nStrength (\\alpha)'),'Position',[min(xlim)+range(xlim)/2 max(ylim)+range(ylim)*.2],'horizontalalignment','center');
    
    
    for n = 2:size(mat,2)
        [~, pval] = ttest(mat(:,1),mat(:,n));
        if pval < .001
            text(n*2-1,max(ylim)+range(ylim)*.04,'***','HorizontalAlignment','center','fontsize',16);
        elseif pval < .01
            text(n*2-1,max(ylim)+range(ylim)*.04,'**','HorizontalAlignment','center','fontsize',16);
        elseif pval < .05
            text(n*2-1,max(ylim)+range(ylim)*.04,'*','HorizontalAlignment','center','fontsize',16);
        end
    end
    
    
    %% previously figure 03 from here
    %% Produces the figure with fixation counts on 8 faces at different ROIs.
    %Draw the winning model on these count profiles (e.g. Gaussian or null
    %model).
    method          = 3;
    [counts,~,~]    = FPSA_FearGen('get_fixation_counts');
    %counts => [faces, rois, subjects, phases]
    m_counts  = nanmean(counts,3);
    s_counts  = std(counts,1,3)./sqrt(size(counts,3));
    nsubs     = length(FPSA_FearGen('get_subjects',current_subject_pool));
    
    [Xgroupfit Ygroupfit pvalgroup]         = FPSA_FearGen('get_groupfit_on_ROIcounts'); %[ph, nroi,100datapoints]
    [Xsubfit Ysubfit params pvalsingle]     = FPSA_FearGen('get_singlesubfits_on_ROIcounts');
    amp                                     = squeeze(params([1 2 3],:,:,1)); %amplitude in percent; params(ph,nroi,sub,[amp kappa offset])
    
    % plot the 3 count-profiles for whole group
    
    ylimmi = min(min(m_counts(:)));
    %     yticki = [0 30 60; 0 15 30; 0 3 6];
    t={'Eyes\n(%%)' 'Nose\n(%%)' 'Mouth\n(%%)'};
    cc = 0;
    % Will equalize ylims of each row of subplots.
    for n = 1:size(Xsubfit,2)
        sax=[];
        for ph = 1:3
            cc = cc + 1;
            hold off;
            sax = [sax subplot(sps(1),sps(2),cc+8)];
            Project.plot_bar(-135:45:180,m_counts(:,n,1,ph));
            if ph == 1
                ylabel(sprintf(t{n}));
            end
            hold on;
            try
                e=errorbar(-135:45:180,m_counts(:,n,1,ph),s_counts(:,n,1,ph),'ok','LineWidth',web,'marker','none','capsize',0);
            catch
                e=errorbar(-135:45:180,m_counts(:,n,1,ph),s_counts(:,n,1,ph),'ok','LineWidth',web,'marker','none');
            end
            set(e,'LineWidth',web,'Color','k')
            if ismember(ph,[1 3])
                plot(squeeze(Xgroupfit(ph,n,:)),squeeze(Ygroupfit(ph,n,:)),'k','Color',[0 0 0],'LineWidth',flw)
            end
            hold off;
            set(gca,'XGrid','off','YGrid','off','XTickLabel',{''})
            if n==3
                set(gca,'XTick',[0 180],'XTickLabels',{'CS+','CS-'});
            end
            %             if ph == 2
            %                 if pttest(nroi) < 0.001
            %                     text(3,max(ylim)+range(ylim)*.04,'*','HorizontalAlignment','center','fontsize',16);
            %                     line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
            %                 end
            %             end
        end
        Publication_Ylim(sax,0,10);
        %         Publication_SymmetricYlim(sax);
        Publication_NiceTicks(sax,1);
        Publication_RemoveXaxis(sax);
        %         Publication_RemoveYaxis(sax(2:3));
        
        %%
        if ph ==3
            cc= cc + 1;
        end
    end
    
    
    
    %%
    %t-tests
    %are amplitudes in Test bigger than in Base?
    for nroi = 1:3
        [hypo(nroi) pttest(nroi)] = ttest(squeeze(amp(1,nroi,:)),squeeze(amp(3,nroi,:)));
    end
    %% single subject fit scatter plot
    subplothelp = [12 16 20];
    liney = [.58 .41 .26];
    xscatter = linspace(1,2,nsubs);
    for nroi = 1:3
        subplot(sps(1),sps(2),subplothelp(nroi))
        hold off;
        mat = squeeze(amp([1 2 3],nroi,:))';
        dotplot(mat)
        axis square;set(gca,'xticklabel',[]);
        Publication_Ylim(gca,0,1);
        Publication_NiceTicks(gca,1);
        
        drawnow;
        if nroi == 3
            set(gca,'xticklabels',{'B' 'C' 'G'})
        end
        if pttest(nroi) < 0.001
            text(3,max(ylim)+range(ylim)*.04,'***','HorizontalAlignment','center','fontsize',16);
            line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
        elseif pttest(nroi) < .01
            text(3,max(ylim)+range(ylim)*.04,'**','HorizontalAlignment','center','fontsize',16);
            line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
        elseif pttest(nroi) < .05
            text(3,max(ylim)+range(ylim)*.04,'*','HorizontalAlignment','center','fontsize',16);
            line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
        end
    end
    %%
    set(GetSubplotHandles(gcf),'fontsize',fs+1);%set all fontsizes to 12
    for i = get(GetSubplotHandles(gcf),'ylabel')';
        set(i{1},'fontweight','bold','VerticalAlignment','bottom','fontsize',fs+2);
    end
    subplotChangeSize(GetSubplotHandles(gcf),.01,.01);
    %%
    if ispc
        fprintf('Done plotting, now saving to %s \n',[homedir 'Documents\Documents\manuscript_selim\figures\figure_02AB_barplot.png'])
        export_fig([homedir 'Documents\Documents\manuscript_selim\figures\figure_02AB_barplot.png'],'-r400')
    end
    %     %% plot rois;
    %     roi = Fixmat([],[]).GetFaceROIs;
    %     roi = double(roi);
    %     roi(roi==0) = .3;
    %     coor = [[110 220 50 445];[221 375 250-90 250+90]; [376 485 250-150 250+150];[0 500 0 500]];%x and y coordinates for left eye (from my perspective), right eye, nose and mouth.
    %
    %     for nroi = 1:3
    %         figure(nroi);clf;
    %         h=imagesc(Fixmat([],[]).stimulus);hold on;
    %         set(h,'alphadata',roi(:,:,nroi));
    %         axis off
    %         axis square
    %         rectangle('Position',[coor(nroi,3) coor(nroi,1) diff(coor(nroi,3:4)) diff(coor(nroi,1:2))])
    %         if ispc
    %             export_fig([homedir 'Documents\Documents\manuscript_selim\' sprintf('ROI_%d.png',nroi)],'-r400')
    %         end
    %     end
    keyboard
elseif strcmp(varargin{1},'figure_05_figure_supplement_1');
    
    [tabl, d] = FPSA_FearGen('get_table_fixfeatures');
    fs = 14;
    data = d.FDMentropy_ChSh.m(:,1:8,:); st_str = {'FDM entropy'};
    % data = reshape(zscore(reshape(data,74,16),0,2),74,8,2);
    data = zscore(data,0,2);
    
    data48 = [data(:,4,1) data(:,4,2) data(:,8,1) data(:,8,2)];
    fg1=figure(1);clf;fg1.Position = [235 246 728 420];
    st = supertitle(st_str);
    subplot(1,2,1);
    Project.plot_bar(-135:45:180,mean(data(:,1:8,1)),std(data(:,1:8,1))./sqrt(length(data)));
    ylim([mean(data(:))-.3*std(data(:)) mean(data(:))+.3*std(data(:))]);title('Baseline');set(gca,'FontSize',fs);
    ylabel('[M +/- SEM]')
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,1));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    
    subplot(1,2,2);
    Project.plot_bar(-135:45:180,mean(data(:,1:8,2)),std(data(:,1:8,2))./sqrt(length(data)));
    ylim([mean(data(:))-.3*std(data(:)) mean(data(:))+.3*std(data(:))]);title('Testphase');set(gca,'FontSize',fs);
    set(st,'FontSize',fs+2)
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,2));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    set(fg1,'Color','w')
    print -dbitmap
    
    st_str = {'fixation N'};
    data = d.fixN.data(:,1:8,:);
    data = zscore(data,0,2);
    data48 = [data(:,4,1) data(:,4,2) data(:,8,1) data(:,8,2)];
    fg1=figure(1);clf;fg1.Position = [235 246 728 420];
    st = supertitle(st_str);
    subplot(1,2,1);
    Project.plot_bar(-135:45:180,mean(data(:,1:8,1)),std(data(:,1:8,1))./sqrt(length(data)));
    % ylim([nanmean(data(:))-std(data(:)) nanmean(data(:))+std(data(:))]);
    title('Baseline');set(gca,'FontSize',fs);
    ylabel('[M +/- SEM]')
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,2));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    
    subplot(1,2,2);
    Project.plot_bar(-135:45:180,mean(data(:,1:8,2)),std(data(:,1:8,2))./sqrt(length(data)));
    % ylim([nanmean(data(:))-nanstd(data(:)) nanmean(data(:))+nanstd(data(:))]);
    title('Testphase');set(gca,'FontSize',fs);
    set(st,'FontSize',fs+2)
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,1));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    set(fg1,'Color','w')
    print -dbitmap
    
    
    
    st_str = {'fixation duration'};
    data = d.fixdur.m(:,1:8,:);
    data = zscore(data,0,2);
    data48 = [data(:,4,1) data(:,4,2) data(:,8,1) data(:,8,2)];
    fg1=figure(1);clf;fg1.Position = [235 246 728 420];
    st = supertitle(st_str);
    subplot(1,2,1);
    Project.plot_bar(-135:45:180,nanmean(data(:,1:8,1)),nanstd(data(:,1:8,1))./sqrt(length(data)));
    ylim([nanmean(data(:))-.4*nanstd(data(:)) nanmean(data(:))+.4*nanstd(data(:))]);title('Baseline');set(gca,'FontSize',fs);
    ylabel('[M +/- SEM]')
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,1));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    
    subplot(1,2,2);
    Project.plot_bar(-135:45:180,nanmean(data(:,1:8,2)),nanstd(data(:,1:8,2))./sqrt(length(data)));
    ylim([nanmean(data(:))-.4*nanstd(data(:)) nanmean(data(:))+.4*nanstd(data(:))]);title('Testphase');set(gca,'FontSize',fs);
    set(st,'FontSize',fs+2)
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,2));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    set(fg1,'Color','w')
    print -dbitmap
    
    
    st_str = {'Saccade distance'};
    data = double(d.saccadedist.m(:,1:8,:));
    data = zscore(data,0,2);
    data48 = [data(:,4,1) data(:,4,2) data(:,8,1) data(:,8,2)];
    fg1=figure(1);clf;fg1.Position = [235 246 728 420];
    st = supertitle(st_str);
    subplot(1,2,1);
    Project.plot_bar(-135:45:180,nanmean(data(:,1:8,1)),nanstd(data(:,1:8,1))./sqrt(length(data)));
    ylim([nanmean(data(:))-nanstd(data(:)) nanmean(data(:))+nanstd(data(:))]);title('Baseline');set(gca,'FontSize',fs);
    ylabel('[M +/- SEM]')
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,1));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    
    subplot(1,2,2);
    Project.plot_bar(-135:45:180,nanmean(data(:,1:8,2)),nanstd(data(:,1:8,2))./sqrt(length(data)));
    ylim([nanmean(data(:))-nanstd(data(:)) nanmean(data(:))+nanstd(data(:))]);title('Testphase');set(gca,'FontSize',fs);
    set(st,'FontSize',fs+2)
    td.x = repmat(-135:45:180,length(data),1);
    td.y = squeeze(data(:,1:8,2));
    td.ids = 1:74;
    t = Tuning(td);
    t.visualization = 0;
    t.GroupFit(3);
    if t.groupfit.ExitFlag ~= 1
        if (10.^-t.groupfit.pval)<.001
            hold on;
            plot(t.groupfit.x_HD,t.groupfit.fit_HD,'k','LineWidth',2)
        end
    end
    set(fg1,'Color','w')
    print -dbitmap
elseif strcmp(varargin{1},'figure_05_figure_supplement_2') %old SFig 3 fixation counts on ROIs
    %% Produces the figure with fixation counts on 8 faces at different ROIs.
    %Draw the winning model on these count profiles (e.g. Gaussian or null
    %model).
    % general layout business.
    fs       = 11; %fontsize
    ms       = 18;  %markersize
    sps      = [3 4]; %subplotsize rows x columns
    flw      = 2; %fitline width
    scatmark = 's';
    scatcol1 = repmat(.5,1,3);%repmat(.8,1,3)
    mbc      = [.7 0 0]; %mean bar color for scatterplots
    web      = 1; %width errorbars
    colors   = [repmat(0.3,3,3)];
    grayshade= [.5 .5 .5];
    alpha_gf = .001;
    
    
    
    current_subject_pool = 0;
    method          = 3;
    [counts,~,~]    = FPSA_FearGen('get_fixation_counts');
    %counts => [faces, rois, subjects, phases]
    m_counts  = nanmean(counts,3);
    s_counts  = std(counts,1,3)./sqrt(size(counts,3));
    nsubs     = length(FPSA_FearGen('get_subjects',current_subject_pool));
    
    [Xgroupfit Ygroupfit pvalgroup]         = FPSA_FearGen('get_groupfit_on_ROIcounts'); %[ph, nroi,100datapoints]
    [Xsubfit Ysubfit params pvalsingle]     = FPSA_FearGen('get_singlesubfits_on_ROIcounts');
    amp                                     = squeeze(params([1 2 3],:,:,1)); %amplitude in percent; params(ph,nroi,sub,[amp kappa offset])
    
    % plot the 3 count-profiles for whole group
    
    ylimmi = min(min(m_counts(:)));
    %     yticki = [0 30 60; 0 15 30; 0 3 6];
    t={'Eyes\n(%%)' 'Nose\n(%%)' 'Mouth\n(%%)'};
    titls = {'Baseline','Conditioning','Generalization'};
    cc = 0;
    % Will equalize ylims of each row of subplots.
    for n = 1:size(Xsubfit,2)
        sax=[];
        for ph = 1:3
            cc = cc + 1;
            hold off;
            sax = [sax subplot(sps(1),sps(2),cc)];
            Project.plot_bar(-135:45:180,m_counts(:,n,1,ph));
            if ph == 1
                ylabel(sprintf(t{n}),'fontsize',fs);
            end
            hold on;
            try
                e=errorbar(-135:45:180,m_counts(:,n,1,ph),s_counts(:,n,1,ph),'ok','LineWidth',web,'marker','none','capsize',0);
            catch
                e=errorbar(-135:45:180,m_counts(:,n,1,ph),s_counts(:,n,1,ph),'ok','LineWidth',web,'marker','none');
            end
            set(e,'LineWidth',web,'Color','k')
            if ismember(ph,[1 3])
                plot(squeeze(Xgroupfit(ph,n,:)),squeeze(Ygroupfit(ph,n,:)),'k','Color',[0 0 0],'LineWidth',flw)
            end
            hold off;
            set(gca,'XGrid','off','YGrid','off','XTickLabel',{''})
            if n==3
                set(gca,'XTick',[0 180],'XTickLabels',{'CS+','CS-'});
            end
            if n == 1
                th(ph) =  title(titls{ph},'fontsize',fs);
            end
        end
        Publication_Ylim(sax,0,10);
        %         Publication_SymmetricYlim(sax);
        Publication_NiceTicks(sax,1);
        Publication_RemoveXaxis(sax);
        %         Publication_RemoveYaxis(sax(2:3));
        
        %%
        if ph ==3
            cc= cc + 1;
        end
    end
    
    
    
    %%
    %t-tests
    %are amplitudes in Test bigger than in Base?
    for nroi = 1:3
        [hypo(nroi) pttest(nroi)] = ttest(squeeze(amp(1,nroi,:)),squeeze(amp(3,nroi,:)));
    end
    %% single subject fit scatter plot
    subplothelp = [4 8 12];
    liney = [.58 .41 .26];
    xscatter = linspace(1,2,nsubs);
    for nroi = 1:3
        subplot(sps(1),sps(2),subplothelp(nroi))
        hold off;
        mat = squeeze(amp([1 2 3],nroi,:))';
        dotplot(mat)
        axis square;set(gca,'xticklabel',[]);
        Publication_Ylim(gca,0,1);
        ylim([-4 4])
        Publication_NiceTicks(gca,1);
        drawnow;
        if nroi == 3
            set(gca,'xticklabels',{'B' 'C' 'G'})
        elseif nroi ==1
            th(4)=title('Tuning Strength (\alpha)','fontsize',fs);
        end
        if pttest(nroi) < 0.001
            text(3,max(ylim)+range(ylim)*.04,'***','HorizontalAlignment','center','fontsize',16);
            line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
        elseif pttest(nroi) < .01
            text(3,max(ylim)+range(ylim)*.04,'**','HorizontalAlignment','center','fontsize',16);
            line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
        elseif pttest(nroi) < .05
            text(3,max(ylim)+range(ylim)*.04,'*','HorizontalAlignment','center','fontsize',16);
            line([1 5],repmat(max(ylim),1,2),'Color',[0 0 0])
        end
    end
    %%
    set(GetSubplotHandles(gcf),'fontsize',12);%set all fontsizes to 12
    for i = get(GetSubplotHandles(gcf),'ylabel')';
        set(i{1},'fontweight','bold','VerticalAlignment','bottom','fontsize',16);
    end
    subplotChangeSize(GetSubplotHandles(gcf),.01,.01);
    %%
    %         SaveFigure(sprintf('%s/data/midlevel/figures/Figure_05_fig_suppl2.png',path_project),'-r300')
    
    
    %     %% plot rois;
    %     roi = Fixmat([],[]).GetFaceROIs;
    %     roi = double(roi);
    
elseif strcmp(varargin{1},'figure_02B_get_params')
    % get single sub params to plot them in fig 2
    
    method = 3;
    force  = 0;
    
    pathparams = sprintf('%sdata/midlevel/params_fit_method_%d.mat',path_project,method);
    
    if ~exist(pathparams)|| force == 1
        % get single subject fit's parameter - SCR
        subs     = FPSA_FearGen('get_subjects');
        scrsubs = subs(ismember(subs,Project.subjects(Project.subjects_scr)));
        
        scr = [];
        scr.params =nan(length(scrsubs),4,2);
        scr.sub    =nan(length(scrsubs),4);
        scr.pval   =nan(length(scrsubs),4);
        sc = 0;
        for n =  scrsubs(:)'
            sc = sc+1;
            s    = Subject(n);
            s.fit_method = 3;
            for ph = [2 4] % Cond no fit, just 2 datapoints
                fit = s.get_fit('scr',ph);
                scr.params(sc,ph,:)    = fit.params(1);
                scr.pval(sc,ph)        = fit.pval;
                scr.sub(sc,ph)         = n;
            end
        end
        scr.valid    = scr.pval > -log10(.05);%selection criteria
        
        % get single subject fit's parameter - Ratings
        
        subs     = FPSA_FearGen('get_subjects');
        rate = [];
        rate.params =nan(length(subs),4,2);
        rate.sub    =nan(length(subs),4);
        rate.pval   =nan(length(subs),4);
        sc = 0;
        for n =  subs(:)'
            sc = sc+1;
            s    = Subject(n);
            s.fit_method = 3;
            for ph = 2:4
                fit = s.get_fit('rating',ph);
                rate.params(sc,ph,:)    = fit.params(1:2);
                rate.pval(sc,ph)        = fit.pval;
                rate.sub(sc,ph)         = n;
            end
        end
        rate.valid    = rate.pval > -log10(.05);%selection criteria
        save(pathparams,'rate','scr')
    else
        fprintf('Found saved file, loading it.\n')
        load(pathparams)
    end
    
    varargout{1} = scr;
    varargout{2} = rate;
    
    
    %%
    %     plot
    clf
    subplot(2,1,1)
    yyaxis left;boxplot(scr.params(:,:,1),'positions',1:4,'Width',.4,'Color','b','boxstyle','filled');
    set(gca,'FontSize',13,'YColor','b')
    yyaxis right;boxplot(scr.params(:,:,2),'positions',6:9,'Width',.4,'Color','k','boxstyle','filled');
    set(gca,'FontSize',13,'YColor','k','YTick',[0:50:150])
    xlim([0 10])
    line([0 5],[0 0],'Color','k')
    set(gca,'XTick',[2 4 7 9],'XTickLabel',{'B','T','B','T'})
    box off
    
    subplot(2,1,2)
    yyaxis left;boxplot(rate.params(:,:,1),'positions',1:4,'Width',.4,'Color','b','boxstyle','filled');
    set(gca,'FontSize',13,'YColor','b')
    yyaxis right;boxplot(rate.params(:,:,2),'positions',6:9,'Width',.4,'Color','k','boxstyle','filled');
    set(gca,'FontSize',13,'YColor','k','YTick',[0:50:150])
    xlim([0 10])
    set(gca,'XTick',[2 3 4 7 8 9],'XTickLabel',{'B','C','T','B','C','T'})
    line([5.5 10],[0 0],'Color','k')
    box off
    
elseif strcmp(varargin{1},'SFig_02_tuneduntuned')
    
    figure(1);
    g                 = Group(FPSA_FearGen('get_subjects'));
    ratings           = g.getRatings(2:4);
    g.tunings.rate{2} = Tuning(g.Ratings(2));
    g.tunings.rate{3} = Tuning(g.Ratings(3));
    g.tunings.rate{4} = Tuning(g.Ratings(4));
    
    g.tunings.rate{2}.GroupFit(8);
    g.tunings.rate{3}.GroupFit(8);
    g.tunings.rate{4}.GroupFit(8);
    %%
    f = figure(1022);
    set(f,'position',[0        0        794         481])
    clf
    for n = 2:4
        sn = n-1;
        subpl(n) =  subplot(2,3,sn);
        if n > 2
            l = line([-150 195],repmat(mean(mean(ratings(:,:,2))),[1 2]),'Color','k','LineWidth',2);
            set(l,'LineStyle',':')
        end
        hold on
        Project.plot_bar(-135:45:180,mean(ratings(:,:,sn)));
        %         Project.plot_bar(mean(ratings(:,:,sn)));
        hold on;
        try
            e        = errorbar(-135:45:180,mean(ratings(:,:,sn)),std(ratings(:,:,sn))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none','capsize',0);
        catch
            e        = errorbar(-135:45:180,mean(ratings(:,:,sn)),std(ratings(:,:,sn))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none');
        end
        set(gca,'XTick',-135:45:180,'YTick',[0 5 10],'FontSize',12)
        %         SetFearGenBarColors(b)
        set(e,'LineWidth',2,'Color','k')
        ylim([0 10])
        xlim([-180 225])
        axis square
        box off
    end
    %
    subplot(2,3,1);ylabel('Rating of p(shock)','FontSize',12)
    hold on;
    %add Groupfit line
    params = [g.tunings.rate{3}.groupfit.Est; g.tunings.rate{4}.groupfit.Est];
    params = [params(:,1) params(:,2) deg2rad(params(:,3)) params(:,4)];
    x = linspace(-150,195,10000);
    
    subplot(2,3,1);
    line([-150 195],repmat(mean(mean(ratings(:,:,2))),[1 2]),'Color','k','LineWidth',2)
    
    subplot(2,3,2);
    plot(x,VonMises(deg2rad(x),params(1,1),params(1,2),params(1,3),params(1,4)),'k-','LineWidth',2)
    line([0 180],[8 8],'Color','k','LineWidth',1.5)
    text(30,8.5,'***','FontSize',20)
    
    subplot(2,3,3);
    plot(x,VonMises(deg2rad(x),params(2,1),params(2,2),params(2,3),params(2,4)),'k-','LineWidth',2)
    line([0 180],[8 8],'Color','k','LineWidth',1.5)
    text(30,8.5,'***','FontSize',20)
    
    clear g
    [~,exclsubs] = FPSA_FearGen('get_subjects');
    g                 = Group(exclsubs);
    ratings           = g.getRatings(2:4);
    g.tunings.rate{2} = Tuning(g.Ratings(2));
    g.tunings.rate{3} = Tuning(g.Ratings(3));
    g.tunings.rate{4} = Tuning(g.Ratings(4));
    
    g.tunings.rate{2}.GroupFit(8);
    g.tunings.rate{3}.GroupFit(8);
    g.tunings.rate{4}.GroupFit(8);
    
    for n = 2:4
        sn = n-1;
        subpl(n) =  subplot(2,3,sn+3);
        if n > 2
            l = line([-150 195],repmat(mean(mean(ratings(:,:,2))),[1 2]),'Color','k','LineWidth',2);
            set(l,'LineStyle',':')
        end
        hold on
        Project.plot_bar(-135:45:180,mean(ratings(:,:,sn)));
        %         Project.plot_bar(mean(ratings(:,:,sn)));
        hold on;
        try %capsize is 2016b compatible.
            e        = errorbar(-135:45:180,mean(ratings(:,:,sn)),std(ratings(:,:,sn))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none','capsize',0);
        catch
            e  =         errorbar(-135:45:180,mean(ratings(:,:,sn)),std(ratings(:,:,sn))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none');
        end
        %         e        = errorbar(-135:45:180,mean(ratings(:,:,sn)),std(ratings(:,:,sn))./sqrt(size(ratings,1)),'ok','LineWidth',web,'marker','none','capsize',0);
        set(gca,'XTick',-135:45:180,'XTickLabel',{'' '' '' 'CS+' '' '' '' 'CS-'},'YTick',[0 5 10],'FontSize',12)
        %         SetFearGenBarColors(b)
        set(e,'LineWidth',2,'Color','k')
        ylim([0 10])
        xlim([-180 225])
        axis square
        box off
    end
    %
    subplot(2,3,4);ylabel('Rating of p(shock)','FontSize',12)
    hold on;
    %add Groupfit line
    params = [g.tunings.rate{3}.groupfit.Est; g.tunings.rate{4}.groupfit.Est];
    params = [params(:,1) params(:,2) deg2rad(params(:,3)) params(:,4)];
    x = linspace(-150,195,10000);
    
    subplot(2,3,4);
    line([-150 195],repmat(mean(mean(ratings(:,:,2))),[1 2]),'Color','k','LineWidth',2)
    
    subplot(2,3,5);
    plot(x,VonMises(deg2rad(x),params(1,1),params(1,2),params(1,3),params(1,4)),'k-','LineWidth',2)
    line([0 180],[8 8],'Color','k','LineWidth',1.5)
    text(30,8.5,'***','FontSize',20)
    
    subplot(2,3,6);
    plot(x,VonMises(deg2rad(x),params(2,1),params(2,2),params(2,3),params(2,4)),'k-','LineWidth',2)
    line([0 180],[8 8],'Color','k','LineWidth',1.5)
    text(30,8.5,'***','FontSize',20)
    
elseif strcmp(varargin{1},'figure_03A') %figure_03A %figure_03B
    %plots the dissimilarity matrices in baseline and generalization phase
    %as well as MDS visualization
    %has to be called like this:
    %FPSA_FearGen_MSc('figure_03A',FPSA_FearGen_MSc('get_fpsa_fair',{'fix' 1:100},1:3))
    %i.e.
    %sim = FPSA_FearGen_MSc('get_fpsa_fair',{'fix' 1:100},1:3);
    %FPSA_FearGen_MSc('figure_03A',sim);
    %% observed similarity matrices
    
    clf
    sim     = varargin{2};
    %
    cormatz = squareform(nanmean(sim.correlation));
    %     cormatz = CancelDiagonals(cormatz,NaN);
    [d u]   = GetColorMapLimits(cormatz,.9);
    d = .9;
    u = 1.3;
    labels  = {sprintf('-135%c',char(176)) sprintf('-90%c',char(176)) sprintf('-45%c',char(176)) 'CS+' sprintf('+45%c',char(176)) sprintf('+90%c',char(176)) sprintf('+135%c',char(176)) 'CS-' };
    labels  = {'' sprintf('-90%c',char(176)) '' 'CS+' '' sprintf('+90%c',char(176)) '' 'CS-' };
    fs      = 12;
    %
    set(gcf,'position',[0 0         995         426]);
    %subplot(9,6,[1 2 3 7 8 9 13 14 15]);
    H(1) = subplot(1,3,1);
    h = imagesc(cormatz(1:8,1:8),[d u]);
    %     set(h,'alphaData',~diag(diag(true(8))));
    axis square;axis off;
    h = text(0,4,'CS+');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(0,8,'CS-');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(0,2,sprintf('-90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',fs*2/3,'rotation',45,'FontWeight','bold');
    h = text(0,6,sprintf('+90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',fs*2/3,'rotation',45,'FontWeight','bold');
    h = text(4,9,'CS+');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(8,9,'CS-');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(2,9,sprintf('-90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',fs*2/3,'rotation',45,'FontWeight','bold');
    h = text(6,9,sprintf('+90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',fs*2/3,'rotation',45,'FontWeight','bold');
    title('Baseline','fontweight','normal','fontsize',fs*3/2,'FontWeight','bold');
    %     subplot(9,6,[4 5 6 10 11 12 16 17 18]);
    H(2) = subplot(1,3,2);
    h=imagesc(cormatz(9:16,9:16),[d u]);
    %     set(h,'alphaData',~diag(diag(true(8))));
    axis square;axis off;
    h = text(4,9,'CS+');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(8,9,'CS-');set(h,'HorizontalAlignment','center','fontsize',fs,'rotation',45,'FontWeight','bold');
    h = text(2,9,sprintf('-90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',fs*2/3,'rotation',45,'FontWeight','bold');
    h = text(6,9,sprintf('+90%c',char(176)));set(h,'HorizontalAlignment','center','fontsize',fs*2/3,'rotation',45,'FontWeight','bold');
    title('Generalization','fontweight','normal','fontsize',fs*3/2,'FontWeight','bold');
    %
    [indices] = FPSA_FearGen('FPSA_CompareB2T');
    [Y X]     = ind2sub([8 8],indices(:,1));
    Y         = Y - .25;
    X         = X - .45;
    hold on;
    fs        = 12;
    for N = 1:length(X);
        if X(N) > Y(N)
            if indices(N,2) < .05 & indices(N,2) > .01;
                if Y(N) == 3.75;
                    text(X(N),Y(N),'*','fontsize',fs,'color','k','FontWeight','bold');
                else
                    text(X(N),Y(N),'*','fontsize',fs,'color','k','FontWeight','bold');
                end
            elseif indices(N,2) < .01 & indices(N,2) > .005;
                text(X(N),Y(N),'**','fontsize',fs,'color','k','FontWeight','bold');
            elseif indices(N,2) < .005 & indices(N,2) > .001;
                text(X(N),Y(N),'***','fontsize',fs,'color','k','FontWeight','bold');
            end
        end
    end
    subplotChangeSize(H(1:2),.035,.035);
    pos = get(gca,'position');
    %% colorbar
    h2              = colorbar;
    set(h2,'location','east');
    h2.AxisLocation ='out';
    h2.Box          = 'off';
    h2.TickLength   = 0;
    h2.Ticks        = [d u];
    h2.TickLabels   = {regexprep(mat2str(round(d*10)/10),'0','') regexprep(mat2str(round(u*10)/10),'0','')};
    
    try
        set(h2,'Position',[pos(1)+pos(3)+.004 pos(2)*2.45 .01 .25])
    end
    h2.FontSize = 12;
    h2.FontWeight='bold';
    % 	set(h2,'Position',pos)
    
    % plot the similarity to cs+
    %     subplot(9,6,[25:27 19:21])
    %%
    H(3) = subplot(1,3,3);
    Y         = FPSA_FearGen('get_mdscale',squareform(mean(sim.correlation)),2);
    y         = reshape(Y,length(Y)/16,16)';
    y      = fliplr(y);
    a =      0;
    rm     = [cos(deg2rad(a)) -sin(deg2rad(a)) ;sin(deg2rad(a)) cos(deg2rad(a)) ];
    y      = (rm*y')';
    colors    = GetFearGenColors;
    colors    = [colors(1:8,:);colors(1:8,:)];
    %
    try
        plot(y([1:8 1],1),y([1:8 1],2),'--','linewidth',3,'color',[0 0 0 .5]);
    catch
        plot(y([1:8 1],1),y([1:8 1],2),'--','linewidth',3,'color',[0 0 0]);
    end
    hold on;
    for nface = 1:8
        try
            scatter(y(nface,1),y(nface,2),500,'markerfacecolor',colors(nface,:),'markeredgecolor',colors(nface,:),'markerfacealpha',.0,'markeredgealpha',.75,'linewidth',2);
            plot(y(nface,1),y(nface,2),'o','markerfacecolor',colors(nface,:),'markeredgecolor',colors(nface,:),'linewidth',2);
        catch
            scatter(y(nface,1),y(nface,2),500,'markerfacecolor',colors(nface,:),'markeredgecolor',colors(nface,:),'linewidth',2);
            plot(y(nface,1),y(nface,2),'o','markerfacecolor',colors(nface,:),'markeredgecolor',colors(nface,:),'linewidth',2);
        end
    end
    box off;axis square;axis tight;axis off
    %
    try
        plot(y([1:8 1]+8,1),y([1:8 1]+8,2),'-','linewidth',3,'color',[0 0 0 1]);
    catch
        plot(y([1:8 1]+8,1),y([1:8 1]+8,2),'-','linewidth',3,'color',[0 0 0]);
    end
    hold on;
    for nface = 1:8
        try
            scatter(y(nface+8,1),y(nface+8,2),500,'markerfacecolor',colors(nface,:),'markeredgecolor',colors(nface,:),'markerfacealpha',1,'markeredgealpha',1);
        catch
            scatter(y(nface+8,1),y(nface+8,2),500,'markerfacecolor',colors(nface,:),'markeredgecolor',colors(nface,:));
        end
    end
    %     text(y(8+4,1)-.02,y(8+4,2)+.065,'CS+','FontWeight','normal','fontsize',12);
    %     text(y(8+8,1)-.08,y(8+8,2)+.07,['CS-'],'FontWeight','normal','fontsize',12);
    plotlims = [-.55 .55];%was .4 before
    xlim(plotlims);
    ylim(plotlims);
    box off;axis square;axis off
    subplotChangeSize(H(3),.04,.04);
    %
    %% legend
    %     plot(plotlims(1),plotlims(2),'ko','markersize',12)
    %     text(plotlims(1)+.05,plotlims(2),'Baseline','fontsize',12);
    %     hold on;
    %     plot(plotlims(1),plotlims(2)-.08,'ko','markersize',12,'markerfacecolor','k');
    %     text(plotlims(1)+.05,plotlims(2)-.08,'Generalization','fontsize',12)
    %     hold off;
    plot(plotlims(2)*.6,plotlims(2),'ko','markersize',12)
    text(plotlims(2)*.6+.05,plotlims(2),'Baseline','fontsize',12);
    hold on;
    plot(plotlims(2)*.6,plotlims(2)-.08,'ko','markersize',12,'markerfacecolor','k');
    text(plotlims(2)*.6+.05,plotlims(2)-.08,'Generalization','fontsize',12)
    hold off;
    %%
    %     SaveFigure(sprintf('%s/data/midlevel/figures/figure_03AB.png',path_project),'-transparent','-r300');
    
    
elseif strcmp(varargin{1},'get_fixation_counts')
    %% Collects fixation counts and reports how they change with conditions on 4 different ROIs before and after learning.
    % these numbers are reported in the manuscript.
    
    
    
    filename       = sprintf('counttuning_ph234_runs_%02d_%02d.mat',runs(1),runs(end));
    
    % need to replace the get_fixmat option from before bc this only ran phase 2 and 4
    subjects = FPSA_FearGen('get_subjects',current_subject_pool);
    path2fixmat = sprintf('%s/data/midlevel/fixmat_ph234_N%02d.mat',path_project,length(subjects));
    
    if exist(path2fixmat)==0 | force;
        fixmat      = Fixmat(subjects,[2 3 4]);%all SUBJECTS, PHASES and RUNS
        fixmat.unitize = 1;
        save(path2fixmat,'fixmat')
    else
        load(path2fixmat);
    end
    
    
    force          = 0;
    c              = 0;
    for ns = subjects(:)'
        fprintf('Counting fixations in subject: %03d.\n',ns);
        c = c+1;
        p = 0;
        dummy_dummy = [];
        for phase = [2 3 4]
            p          = p + 1;
            path_write = sprintf('%s/data/sub%03d/p%02d/midlevel/%s.mat',path_project,ns,phase,filename);
            %
            if exist(path_write) ==0 | force;
                %
                cc = 0;
                v  = [];
                for ncond = fixmat.realcond
                    cc   = cc+1;
                    v{cc} = {'subject' ns 'deltacsp' ncond 'phase' phase};
                end
                %
                fixmat.getmaps(v{:});
                %
                for iii = 1:size(fixmat.maps,3)
                    dummy_counts(iii,:) = fixmat.EyeNoseMouth(fixmat.maps(:,:,iii),0);
                end
                save(path_write,'dummy_counts');
            else
                load(path_write);
            end
            count_dm(:,:,c,p) = demean(dummy_counts);
            count(:,:,c,p) = dummy_counts;%[faces organs subjects phases] %keeping this to report % in each ROI without already demeaning them
            dummy_dummy = [ dummy_dummy ; dummy_counts];
        end %
        dummy_dummy([9 10 11 13 14 15],:) = NaN;
        dummy_dummy                       = nanzscore(dummy_dummy);
        %[face rois subjects phases]
        count_z(:,:,c,1)                  = dummy_dummy(1:8,:);
        count_z(:,:,c,2)                  = dummy_dummy(9:16,:);
        count_z(:,:,c,3)                  = dummy_dummy(17:24,:);
    end
    varargout{1} = count*100;
    varargout{2} = count_dm;
    varargout{3} = count_z;
    %     %these groups are for the venn plot later.
    %     groups.g1 = repmat([1:8]',[1 5 61 2]);
    %     groups.g2 = repmat(1:5,[8 1 61 2]);
    %     groups.g3 = repmat(reshape(1:61,[1 1 61]),[8 5 1 2]);
    %     groups.g4 = repmat(reshape(1:2,[1 1 1 2]),[8 5 61 1]);
    %
    %     varargout{2} = groups;
    %% Compute fixation density and their change.
    P = nanmean(nanmean(nanmean(count(:,1:3,:,1:3),4),3));
    fprintf('Mean fixation density in percentage in Baseline, Conditioning + Generalization:\n')
    fprintf('%25s %3.5g\n','Eyes:', P(1))
    fprintf('%25s %3.5g\n','Nose:',P(2))
    fprintf('%25s %3.5g\n','Mouth:',P(3))
    %
    P = mean(mean(count(:,1:3,:,3),3))-mean(mean(count(:,1:3,:,1),3));
    fprintf('Change in Fixation Density in percentage (Generalization - Baseline):\n');
    fprintf('%25s %3.5g\n','Delta Eyes:', P(1))
    fprintf('%25s %3.5g\n','Delta Nose:',P(2))
    fprintf('%25s %3.5g\n','Delta Mouth:',P(3))
    
elseif strcmp(varargin{1},'anova_count_tuning');
    %% will fit a model to the density changes.
    [count groups] = FPSA_FearGen('get_fixation_counts');
    %remove the last ROI
    count(:,5,:,:) = [];
    groups.g1(:,5,:,:) = [];
    groups.g2(:,5,:,:) = [];
    groups.g3(:,5,:,:) = [];
    groups.g4(:,5,:,:) = [];
    
    
    Y = Vectorize(count(:,:,:,1)-count(:,:,:,2));
    
    t = table(Y(:),abs(groups.g1(1:1952)-4)',categorical( groups.g2(1:1952)'),categorical( groups.g3(1:1952)'),'variablenames',{'count' 'faces' 'roi' 'subjects'});
    a = fitlm(t,'count ~ 1 + faces + roi + faces*roi')
    
elseif strcmp(varargin{1},'get_groupfit_on_ROIcounts')
    
    force = 0;
    onlywinnersgetacurve = 1;
    method = 3;
    subs = FPSA_FearGen('get_subjects');
    path2fit = fullfile(path_project,'data','midlevel',sprintf('groupfit_counts_ph1to3_N%02d.mat',length(subs)));
    
    if ~exist(path2fit) || force == 1
        [counts]   = FPSA_FearGen('get_fixation_counts');
        %% fit group for each phase
        X_fit = [];
        Y_fit = [];
        for ph = [1 3]
            for nroi = 1:size(counts,2)-1
                data.y   = squeeze(counts(:,nroi,:,ph))';
                data.x   = repmat(-135:45:180,size(counts,3),1);
                data.ids = [1:size(counts,3)]';
                t        = [];
                t        = Tuning(data);
                t.GroupFit(method);
                X_fit(ph,nroi,:) = t.groupfit.x_HD;
                pval(ph,nroi)    = 10.^-t.groupfit.pval;
                if onlywinnersgetacurve == 1
                    if t.groupfit.pval > -log10(.05)
                        Y_fit(ph,nroi,:) = t.groupfit.fit_HD;
                    else
                        Y_fit(ph,nroi,:) = repmat(mean(t.y(:)),[1 length(t.groupfit.fit_HD)]);
                    end
                else
                    Y_fit(ph,nroi,:) = t.groupfit.fit_HD;
                end
            end
        end
        save(path2fit,'X_fit','Y_fit','pval','t')
    else
        load(path2fit)
    end
    varargout{1} = X_fit;
    varargout{2} = Y_fit;
    varargout{3} = pval;
    varargout{4} = t;
    
elseif strcmp(varargin{1},'get_singlesubfits_on_ROIcounts')
    force  = 0;
    method = 3;
    subs   = FPSA_FearGen('get_subjects');
    nsubs        = length(subs);
    [~,~,counts] = FPSA_FearGen('get_fixation_counts');
    path_write   = sprintf('%s/data/midlevel/ROI_fixcount_ph234_singlesub_fit_%d_N%d.mat',path_project,method,size(counts,3));
    
    if ~exist(path_write) || force==1
        
        %% fit single subs
        nphases = 3;
        totalroi = 3;
        X_fit = nan(nphases,totalroi,nsubs,100);
        Y_fit = nan(nphases,totalroi,nsubs,100);
        pval = nan(nphases,totalroi,nsubs);
        params = nan(nphases,totalroi,nsubs,3);
        for sub = 1:size(counts,3)
            for ph = [1 3]
                for nroi = 1:totalroi
                    data.y   = squeeze(counts(:,nroi,sub,ph))';
                    data.x   = repmat(-135:45:180,1);
                    data.ids = sub';
                    t        = [];
                    t        = Tuning(data);
                    t.SingleSubjectFit(method);
                    pval(ph,nroi,sub) = 10.^-t.fit_results.pval;
                    params(ph,nroi,sub,:) = t.fit_results.params;
                    X_fit(ph,nroi,sub,:) = t.fit_results.x_HD;
                    if t.fit_results.pval > -log10(.05)
                        Y_fit(ph,nroi,sub,:) = t.fit_results.y_fitted_HD;
                    else
                        Y_fit(ph,nroi,sub,:) = repmat(mean(t.y(:)),[1 length(t.fit_results.y_fitted_HD)]);
                    end
                end
            end
        end
        save(path_write,'X_fit','Y_fit','params','pval')
    else
        load(path_write)
    end
    varargout{1} = X_fit;
    varargout{2} = Y_fit;
    varargout{3} = params;
    varargout{4} = pval;
elseif strcmp(varargin{1},'behavior_correlation');
    %% Computes correlation with behavior
    
    b      = FPSA_FearGen('get_behavior');%amplitude of the scr response
    fixmat = FPSA_FearGen('get_fixmat');
    %
    a2 = FPSA_FearGen('fix_counts',fixmat,1,15);
    a  = FPSA_FearGen('beta_counts',fixmat,1,15);
    %%
    try
        b.rating_03_center  = abs(b.rating_03_center);
        b.rating_04_center  = abs(b.rating_04_center);
        b.scr_04_center     = abs(b.scr_04_center);
        %corrected improvement:
        %
        %         b.rating_04_center_improvement  = abs(b.rating_03_center-b.rating_04_center)*-1
        %         b.rating_04_center              = ;
        %         b.scr_04_center                 = abs(b.scr_04_center);
    end
    b.rating_04_sigma_y     = [];
    b.rating_03_sigma_y     = [];
    b.rating_03_offset      = [];
    b.rating_04_offset      = [];
    b.subject               = [];
    b.scr_04_offset         = [];
    b.scr_04_sigma_y        = [];
    
    %     b.scr_04_logkappa       =  log(b.scr_04_kappa);
    %     b.rating_03_logkappa    =  log(b.rating_03_kappa);
    %     b.rating_04_logkappa    =  log(b.rating_04_kappa);
    
    b.si                    =  b.rating_03_kappa    - b.rating_04_kappa;
    %     b.silog                 =  b.rating_03_logkappa - b.rating_04_logkappa;
    %
    addpath('/home/onat/Documents/Code/Matlab/CircStat/');
    dummy = deg2rad([b.rating_04_center  b.rating_03_center]);
    %     b.sip                    =  ((pi - circ_mean(dummy'))./circ_std(dummy'))';
    b.sip                    =  diff(dummy')';
    %
    vnames                  = sort(b.Properties.VariableNames);
    bb = table();
    for n = vnames
        bb.(n{1})=double(b.(n{1}));
    end
    data                    = [a2(:,:,1) a2(:,:,2) a(:,:,1) a(:,:,2) table2array(bb)];
    %%
    figure;
    imagesc(corrcov(nancov(data)).^2,[-.4 .4])
    hold on;
    plot([6 6]-.5+0,ylim,'r')
    plot([6 6]-.5+5,ylim,'r','linewidth',4)
    plot([6 6]-.5+10,ylim,'r')
    plot([6 6]-.5+15,ylim,'r','linewidth',4)
    plot([6 6]-.5+18,ylim,'r')
    plot([6 6]-.5+21,ylim,'r')
    %     plot([6 6]-.5+19,ylim,'r','linewidth',4)
    %     plot([6 6]-.5+16,ylim,'r')
    %     plot([6 6]-.5+22,ylim,'r')
    %     plot([6 6]-.5+25,ylim,'r','linewidth',4)
    %     plot(xlim,[6 6]-.5+25,'r','linewidth',4)
    %     plot(xlim,[6 6]-.5+22,'r')
    %     plot(xlim,[6 6]-.5+19,'r','linewidth',4)
    %     plot(xlim,[6 6]-.5+16,'r')
    plot(xlim,[6 6]-.5+21,'r');
    plot(xlim,[6 6]-.5+18,'r');
    plot(xlim,[6 6]-.5+15,'r','linewidth',4)
    plot(xlim,[6 6]-.5+10,'r')
    plot(xlim,[6 6]-.5+5,'r','linewidth',4)
    plot(xlim,[6 6]-.5+0,'r')
    hold off
    colorbar;axis square;
    set(gca,'ytick',1:size(data,2),'yticklabel',['eyel' 'eyer' 'nose' 'mouth' 'all' 'eyel' 'eyer' 'nose' 'mouth' 'all' 'eyel' 'eyer' 'nose' 'mouth' 'all' 'eyel' 'eyer' 'nose' 'mouth' 'all' vnames],'ticklabelinterpreter','none');axis square;
    set(gca,'xtick',1:size(data,2),'xticklabel',['eyel' 'eyer' 'nose' 'mouth' 'all' 'eyel' 'eyer' 'nose' 'mouth' 'all' 'eyel' 'eyer' 'nose' 'mouth' 'all' 'eyel' 'eyer' 'nose' 'mouth' 'all' vnames],'ticklabelinterpreter','none','XTickLabelRotation',90);
  
     %SaveFigure(sprintf('%sdata/midlevel/figures/BehavioralCorrelation.png',path_project),'-transparent');
    
    model = corrcov(getcorrmat([2 2],5,0,1));% - corrcov(getcorrmat([1 1],1,0,1))
    %
elseif strcmp(varargin{1},'Figure_03_figure_supplement_2')%models_run1_run2_run3
    
    filename     = sprintf('%s/data/midlevel/REVISION_fpsa_fair_kernel_fwhm_%03d_subjectpool_%03d_run_1-2-3.mat',path_project,kernel_fwhm,current_subject_pool);
    C1 =  FPSA_FearGen('runs',1,'FPSA_model_singlesubject',{'fix',1:100});
    C2 =  FPSA_FearGen('runs',2,'FPSA_model_singlesubject',{'fix',1:100});
    C3 =  FPSA_FearGen('runs',3,'FPSA_model_singlesubject',{'fix',1:100});
    
    
    spec_base = C1.model_02.w1(:,1); %=C3.model_02.w1(:,1);
    spec_test1 = C1.model_02.w1(:,2);
    spec_test2 = C2.model_02.w1(:,2);
    spec_test3 = C3.model_02.w1(:,2);
    unspec_base    = C1.model_02.w1(:,1); %=C3.model_02.w1(:,1);
    unspec_test1 =  C1.model_02.w2(:,2);
    unspec_test2 =  C2.model_02.w2(:,2);
    unspec_test3 =  C3.model_02.w2(:,2);
    spec = [spec_base spec_test1 spec_test2 spec_test3];
    unspec = [unspec_base unspec_test1 unspec_test2 unspec_test3];
    
    figure;
    errorbar([.95 1.95 2.95 3.95],mean(spec),std(spec)./sqrt(length(spec)),'r','LineWidth',2)
    hold on;
    errorbar([1.05 2.05 3.05 4.05],mean(unspec),std(unspec)./sqrt(length(unspec)),'k','LineWidth',2)
    legend('spec','unspec')
    set(gca,'XTick',1:4,'XTickLabel',{'Base','Gen_run1','Gen_run2','Gen_run3'},'FontSize',14);
    set(gcf,'color','w')
    ylabel('beta (M +/- SEM)')
    box off
    [ht pt] = ttest(unspec_test3,unspec_test1)
    [ht pt] = ttest(spec_test1,unspec_test1)
    %     SaveFigure(sprintf('%s/data/midlevel/figures/Figure_03_figure_supplement_2.png',path_project),'-transparent','-r300');
    
    keyboard
    MT = table(unspec_base,unspec_test1,unspec_test2,unspec_test3,...
    spec_base,spec_test1,spec_test2,spec_test3);
    csvwrite(strrep(filename,'.mat','.csv'),MT,1,0)
    writetable(MT,strrep(filename,'.mat','.csv')) %taken to JASP for rmANOVA.
    save(filename,'spec','unspec','MT');
    
elseif strcmp(varargin{1},'Figure_03_figure_supplement_1') %%corr_with_rate_scr
    
    t = FPSA_FearGen('get_table_behavior');
    
    [rhoR pvalR] = corr(t.beta_diff_test,t.rating_test_parametric);
    [rhoS pvalS] = corr(t.beta_diff_test(~isnan(t.scr_test_parametric)),t.scr_test_parametric(~isnan(t.scr_test_parametric)));
    [rhoRspec pvalRspec] = corr(t.beta1_test,t.rating_test_parametric);
    [rhoSspec pvalSspec] = corr(t.beta1_test(~isnan(t.scr_test_parametric)),t.scr_test_parametric(~isnan(t.scr_test_parametric)));
    
    %% Figure_03_figure_supplement_1
    fs =  14;
    fg = figure;
    fg.Position(3:4) = [750 350];
    subplot(1,2,1);
    hold on;
    scatter(t.beta_diff_test,t.rating_test_parametric,'filled');
    lsl = lsline;set(lsl,'LineWidth',2);
    xlabel('FPSA anisotropy (spec-unspec)')
    ylabel('Rating tuning \alpha')
    ylimmi = ylim;
    tt=text(.45,ylimmi(1)*.6,sprintf('r = %04.2f\np = %04.2f',rhoR,pvalR));set(tt,'FontSize',fs)
    subplot(1,2,2);
    hold on;
    scatter(t.beta_diff_test(~isnan(t.scr_test_parametric)),t.scr_test_parametric(~isnan(t.scr_test_parametric)),'filled');
    lsl = lsline;set(lsl,'LineWidth',2);
    xlabel('FPSA anisotropy (spec-unspec)')
    ylabel('SCR tuning \alpha')
    ylimmi = ylim;
    tt=text(.45,ylimmi(1)*.6,sprintf('r = %04.2f\np = %04.2f',rhoS,pvalS));set(tt,'FontSize',fs)
    for ns = 1:2;
        subplot(1,2,ns);
        xL = get(gca, 'XLim');plot(xL, [0 0], 'k--')
        yL = get(gca, 'YLim');plot([0 0],yL,  'k--')
        set(gca,'FontSize',fs)
        axis square
    end
    %     SaveFigure(sprintf('%s/data/midlevel/figures/Figure_03_figure_supplement_1.png',path_project),'-transparent','-r300');
elseif strcmp(varargin{1},'get_table_fixfeatures'); %% returns parameter of the behaviral recordings
    %%
    % Target: What features of fixation behavior predict the anisotropy
    % from model_02?
    % Steps:
    % collect necessary data
    % set up table
    force_t  = 0;
    force_d  = 0;
    
    zscore_wanted =1;
    bc_wanted = 0;
    p        = Project;
    subs     = FPSA_FearGen('get_subjects');
    
    path2table = sprintf('%s/data/midlevel/table_fixfeatures_N%d_zscore%d_bc%d.mat',path_project,length(subs),zscore_wanted,bc_wanted);
    
    if ~exist(path2table)||force_t == 1
        
        %% get model parameters
        C          = FPSA_FearGen('FPSA_model_singlesubject',{'fix',1:100});
        beta1_base         = C.model_02.w1(:,1);
        beta2_base         = C.model_02.w2(:,1);
        beta1_test         = C.model_02.w1(:,2);
        beta2_test         = C.model_02.w2(:,2);
        beta1_diff         = C.model_02.w1(:,2)-C.model_02.w1(:,1);
        beta2_diff         = C.model_02.w2(:,2)-C.model_02.w2(:,1);
        beta_diff_test     = beta1_test - beta2_test;
        beta_diffdiff      = (beta1_test - beta2_test) - (beta1_base - beta2_base);%how much does w1 increase more than w2 does? (Interaction)
        %%
        if ~exist(strrep(path2table,'table','data'))|| force_d ==1
            fix = FPSA_FearGen('get_fixmat');
            
            %mean number of fixations for this combination
            [d.fixN.data, d.fixN.info] = fix.histogram;
            
            sc = 0;
            for sub = unique(fix.subject)
                fprintf('\nWorking on sub %02d, ',sub)
                sc= sc+1;
                pc = 0;
                for ph = [2 4]
                    fprintf('phase %d. ',ph)
                    pc = pc+1;
                    cc=0;
                    for cond = unique(fix.deltacsp)
                        cc=cc+1;
                        ind = logical((fix.subject==sub).*(fix.phase == ph).* (fix.deltacsp == cond));
                        %mean duration of fixations for this phase/sub/cond
                        d.fixdur.m(sc,cc,pc) = mean(fix.stop(ind)-fix.start(ind));
                        %% for entropy, we need single trials, otherwise the trial number contributing to mean FDM (for this cond-phase-sub) biases the entropy computation
                        %mean entropy for this combination
                        
                        tc = 0;
                        for tr = unique(fix.trialid(ind)) %loop through trials of this cond-phase-sub
                            tc = tc+1;
                            fix.unitize = 0;
                            fix.getmaps({'trialid' tr 'phase' ph 'subject' sub 'deltacsp' cond});
                            FDMent_u0(tc)     = FPSA_FearGen('FDMentropy',fix.vectorize_maps);
                            FDMent_ChSh(tc)     = FPSA_FearGen('FDMentropy_ChaoShen',fix.vectorize_maps);
                            
                            %% collect saccade lengths here, will ya!?
                            ind_trial = logical(ind.*[fix.trialid == tr]);
                            fixes = [fix.x(ind_trial)' fix.y(ind_trial)'];
                            for nfix = 1:sum(ind_trial)-1
                                saccdist_perfix(nfix) = pdist(fixes(nfix:nfix+1,:),'euclidean');
                            end
                            saccade_dist(tc) = mean(saccdist_perfix);
                        end
                        d.FDMentropy_u0.m(sc,cc,pc) = mean(FDMent_u0);
                        d.FDMentropy_ChSh.m(sc,cc,pc) = mean(FDMent_ChSh);
                        d.saccadedist.m(sc,cc,pc)   = mean(saccade_dist);
                        fix.unitize = 1;
                    end
                end
            end
            save(strrep(path2table,'table','data'),'d','subs');
        else
            load(strrep(strrep(path2table,'table','data'),sprintf('_zscore%d_bc%d',zscore_wanted,bc_wanted),''))
            
        end
        base = 1;
        test = 2;
        spec = [4 8];
        unspec = [6 2];
        
        if zscore_wanted==1
            d.fixN.data = zscore( d.fixN.data,0,2);
            d.fixdur.m = zscore( d.fixdur.m,0,2);
            d.saccadedist.m = zscore( d.saccadedist.m,0,2);
            d.FDMentropy_ChSh.m = zscore( d.FDMentropy_ChSh.m,0,2);
        end
        if bc_wanted == 1 %baseline correction.
            anis_fixN     = ((d.fixN.data(:,spec(1),test)-d.fixN.data(:,spec(1),base))- (d.fixN.data(:,spec(2),test)-d.fixN.data(:,spec(2),base)))-((d.fixN.data(:,unspec(1),test)-d.fixN.data(:,unspec(1),base))- (d.fixN.data(:,unspec(2),test)-d.fixN.data(:,unspec(2),base))); %baseline corrected diff_CSPCSN - diff_plus90degminus90degrees
            anis_fixdur   = ((d.fixdur.m(:,spec(1),test)-d.fixdur.m(:,spec(1),base))- (d.fixdur.m(:,spec(2),test)-d.fixdur.m(:,spec(2),base)))-((d.fixdur.m(:,unspec(1),test)-d.fixdur.m(:,unspec(1),base))- (d.fixdur.m(:,unspec(2),test)-d.fixdur.m(:,unspec(2),base))); %baseline corrected diff_CSPCSN - diff_plus90degminus90degrees
            anis_saccdist = ((d.saccadedist.m(:,spec(1),test)-d.saccadedist.m(:,spec(1),base))-(d.saccadedist.m(:,spec(2),test)-d.saccadedist.m(:,spec(2),base))...
                -(d.saccadedist.m(:,unspec(2),test)-d.saccadedist.m(:,unspec(2),base))-(d.saccadedist.m(:,spec(2),test)-d.saccadedist.m(:,spec(2),base)));
            anis_entr      = ((d.FDMentropy_ChSh.m(:,spec(1),test)-d.FDMentropy_ChSh.m(:,spec(1),base))- (d.FDMentropy_ChSh.m(:,spec(2),test)-d.FDMentropy_ChSh.m(:,spec(2),base)))-((d.FDMentropy_ChSh.m(:,unspec(1),test)-d.FDMentropy_ChSh.m(:,unspec(1),base))- (d.FDMentropy_ChSh.m(:,unspec(2),test)-d.FDMentropy_ChSh.m(:,unspec(2),base))); %ba
        else
            anis_fixN     = (d.fixN.data(:,spec(1),test)- d.fixN.data(:,spec(2),test))-(d.fixN.data(:,unspec(1),test)-d.fixN.data(:,unspec(2),test)); %baseline corrected diff_CSPCSN - diff_plus90degminus90degrees
            anis_fixdur   = (d.fixdur.m(:,spec(1),test)-d.fixdur.m(:,spec(2),test))-(d.fixdur.m(:,unspec(1),test)-d.fixdur.m(:,unspec(2),test)); %baseline corrected diff_CSPCSN - diff_plus90degminus90degrees
            anis_saccdist = (d.saccadedist.m(:,spec(1),test)-d.saccadedist.m(:,spec(2),test))-(d.saccadedist.m(:,unspec(1),test)-d.saccadedist.m(:,spec(2),test));
            anis_entr      = (d.FDMentropy_ChSh.m(:,spec(1),test)-d.FDMentropy_ChSh.m(:,spec(2),test))-(d.FDMentropy_ChSh.m(:,unspec(1),test))-(d.FDMentropy_ChSh.m(:,unspec(1),test)-d.FDMentropy_ChSh.m(:,unspec(2),test)); %ba
            
        end
        
        %% concatenate everything in the table
        t = table(subs(:),...
            beta1_base,beta2_base,beta1_test,beta2_test,beta1_diff,beta2_diff,beta_diff_test,beta_diffdiff,anis_fixN,anis_fixdur,anis_saccdist,anis_entr,...
            'variablenames',{'subject_id' ,'beta1_base','beta2_base','beta1_test','beta2_test','beta1_diff','beta2_diff','beta_diff_test','beta_diffdiff','anis_fixN','anis_fixdur','anis_saccdist','anis_entr'});
        save(path2table,'t');
    else
        fprintf('Found table at %s, loading it.\n',path2table)
        load(path2table);
        load(strrep(path2table,'table','data'));
    end
    %%
    varargout{1} = t;
    varargout{2} = d;
elseif strcmp(varargin{1},'GLM_fixfeatures')
    force    = 0;
    p        = Project;
    subs     = FPSA_FearGen('get_subjects');
    zscore_wanted = 1;
    bc_wanted = 0;
    path2table = sprintf('%sdata/midlevel/table_fixfeatures_N%d_zscore%d_bc%d.mat',path_project,length(subs),zscore_wanted,bc_wanted);
    
    if ~exist(path2table) || force == 1
        t  = FPSA_FearGen('get_table_fixfeatures');
    else
        load(path2table);
        %         load(strrep(path2table,'table','data'));
    end
    
    mat = [t.anis_fixN t.anis_fixdur t.anis_saccdist t.anis_entr];
    [cmat, pmat] = corrcoef(mat);
    figure;
    h = imagesc(cmat,[-1 1]);
    hold on;
    mask = double(pmat<.05);
    mask(mask == 0) = .15;
    colorbar
    set(h,'AlphaData',mask);
    hh=ImageWithText(cmat,cmat,[-1 1]);
    set(hh,'AlphaData',0);
    hold on;
    set(gca,'XTick',1:4,'YTick',1:4,'XTicklabel',{'fixN','fixDur','SaccDist','Entr'},'YTicklabel',{'fixN','fixDur','SaccDist','Entr'})
    axis image;box off
    
    model          = fitlm(t,'beta_diff_test ~ 1 + anis_fixN + anis_fixdur + anis_saccdist + anis_entr');
    
elseif strcmp(varargin{1},'FDMentropy')
    % computes entropy of a fixation density map.
    % Map should be normalized anyway. If not, this function does it.
    %% THIS IS BIASED BY NUMBER OF FIXATIONS.
    
    
    % remove zero entries in p
    fdm = varargin{2};
    fdm(fdm==0) = [];
    
    if sum(fdm) ~=0
        % normalize p so that sum(p) is one.
        fdm = fdm ./ numel(fdm);
    end
    
    E = -sum(fdm.*log2(fdm));
    varargout{1} = E;
elseif strcmp(varargin{1},'FDMentropy_ChaoShen')
    
    % entropy compuation with Chao-Shen KL correction (see Wilming et al.,
    % 2011)
    % q needs to be an FDM where sum ~= 1
    
    q = varargin{2};
    yx = q(q > 0); % remove bins with zero counts
    n = sum(yx);
    p = yx/n;
    f1 = sum(yx == 1); % number of singletons in the sample
    if f1 == n % avoid C == 0
        f1 = f1 - 1;
    end
    C = 1 - (f1/n); % estimated coverage of the sample
    pa = C * p; % coverage adjusted empirical frequencies
    la = (1 - (1 - pa).^n); % probability to see a bin (species) in the sample
    H = -sum((pa.* log2(pa))./ la);
    
    varargout{1} = H;
    varargout{2} = pa;
    varargout{3} = la;
    
elseif strcmp(varargin{1},'compare_binary2Gauss_singlesub')
    %% all this is evolution trying out different binary function to give them the best shot.
    %% RATINGS.
    subs = FPSA_FearGen('get_subjects');
    path2modelfits = sprintf('%sdata/midlevel/Ratings_binary2Gauss_N%d_fits_3_14.mat',path_project,length(subs));
    nullrater = zeros(length(subs),3);
    if ~exist(path2modelfits) || force == 1
        sc = 0;
        for sub = subs(:)'
            sc = sc+1;
            s = Subject(sub);
            for ph = 1:3
                t = Tuning(s.get_rating(ph+1));
                t.visualization = 0;
                t.SingleSubjectFit(3);
                params_Gauss(:,sc,ph) = t.fit_results.params;
                LL_Gauss(sc,ph) = t.fit_results.Likelihood;
                LL_null(sc,ph)  = t.fit_results.null_Likelihood;
                %                 t.SingleSubjectFit(10);
                %                 LL_bin_miny(sc,ph)   = t.fit_results.Likelihood;
                %                 t.SingleSubjectFit(11);
                %                 LL_bin_meany(sc,ph)   = t.fit_results.Likelihood;
                %                 t.SingleSubjectFit(12);
                %                 LL_bin_freey(sc,ph)   = t.fit_results.Likelihood;
                %                 params_bin_freey(:,sc,ph) = t.fit_results.params;
                t.SingleSubjectFit(14);
                LL_bin_freey14(sc,ph)   = t.fit_results.Likelihood;
                params_bin_freey14(:,sc,ph) = t.fit_results.params;
                
            end
            if std(t.y) == 0
                nullrater(sc,ph) = 1;
            end
        end
        try
            save(path2modelfits,'params_Gauss','LL_Gauss','LL_null','LL_bin_freey14','params_bin_freey14','nullrater')
        catch
            keyboard
        end
    else
        load(path2modelfits)
    end
    
    %     t = Tuning(Subject(1).get_rating(4));
    %     figure;
    %     b = bar(-135:45:180,t.y_mean);
    %     set(b,'FaceAlpha',.3,'EdgeColor','none')
    %     t.visualization = 0;
    %     t.SingleSubjectFit(3);
    %     hold on;
    %     plot(t.fit_results.x_HD,t.fit_results.y_fitted_HD,'r','LineWidth',2)
    %     hold on
    %     t.SingleSubjectFit(10)
    %     plot(t.fit_results.x_HD,t.fit_results.y_fitted_HD,'g','LineWidth',2)
    %     t.SingleSubjectFit(11);
    %     plot(t.fit_results.x_HD,t.fit_results.y_fitted_HD,'c','LineWidth',2)
    %     t.SingleSubjectFit(12);
    %     plot(t.fit_results.x_HD,t.fit_results.y_fitted_HD,'b','LineWidth',2)
    %     legend('rating','Gauss','binary min(y)','binary mean(y)','binary free_y')
    %     box off
    %
    %     keyboard
    %     %   %% which model wins on subject level?
    %     df = t.fit_results.dof;
    %     pval_Gauss_vs_miny   = (1-chi2cdf(-2*(LL_Gauss - LL_bin_miny),df) + eps);
    %     pval_Gauss_vs_meany  = (1-chi2cdf(-2*(LL_Gauss - LL_bin_meany),df) + eps);
    %     pval_Gauss_vs_freey  = (1-chi2cdf(-2*(LL_Gauss - LL_bin_freey),df) + eps);
    %
    %     N_Gauss_miny = sum(pval_Gauss_vs_miny<.05);
    %     N_Gauss_meany = sum(pval_Gauss_vs_meany<.05);
    %     N_Gauss_freey = sum(pval_Gauss_vs_freey<.05);
    %
    %     %is this sign. diff from chance?
    %     BinomPval_Gaussminy  = binopdf(N_Gauss_miny,length(subs),.5); %.5 for chance level.
    %     BinomPval_Gaussmeany = binopdf(N_Gauss_meany,length(subs),.5);
    
    %     param_G = 2;
    %     param_B = 3;
    %     aic_gauss     =  2*LL_Gauss + 2*param_G; %number of params
    %     aic_bin_freey =  2*LL_bin_freey + 2*param_B;
    %     aic_bin_miny  =  2*LL_bin_miny + 2*(param_B-1);
    %     aic_bin_meany =  2*LL_bin_meany + 2*(param_B-1);
    %     gausswins_freeY =(aic_gauss<aic_bin_freey);
    %     gausswins_minY  =(aic_gauss<aic_bin_miny);
    %     gausswins_meanY =(aic_gauss<aic_bin_meany);
    %     BinomPval_GaussfreeY  = binopdf(sum(gausswins_freeY),length(subs),.5); %.5 for chance level.
    %     BinomPval_GaussmeanY = binopdf(sum(gausswins_meanY),length(subs),.5);
    %     BinomPval_GaussminY = binopdf(sum(gausswins_minY),length(subs),.5);
    
    %
    %     %do the individual fits correlate?
    %     [rho,pval] = corr(params_Gauss(:,1,3),params_bin_freey(:,1,3)) %%LK
    %
    %     %%what about a Gauss with free Y?
    %     for ns=1:74
    %         for ph = 1:3
    %             t = Tuning(Subject(subs(ns)).get_rating(ph+1));
    %             t.visualization = 0;
    %             t.SingleSubjectFit(13);
    %             params_GaussY(:,ns,ph) = t.fit_results.params;
    %             LL_GaussY(ns,ph) = t.fit_results.Likelihood;
    %         end
    %     end
    
    %     %% single sub example fig
    %      figure
    %      ns = 1;
    %         t = Tuning(Subject(subs(1)).get_rating(4));
    %         t.visualization = 0;
    %         t.SingleSubjectFit(3);
    %         b = bar(-135:45:180,t.y_mean);
    %         set(b,'FaceAlpha',.3,'EdgeColor','none')
    %         hold on
    %         plot(t.x,t.y,'o','MarkerFaceColor',[.8 .8 .8])
    %         plot(t.fit_results.x_HD,t.make_gaussian_fmri_zeromean(t.fit_results.x_HD,params_Gauss(1,ns,3),params_Gauss(2,ns,3))+mean(t.y_mean),'r','LineWidth',2)
    %
    %         hold on
    % %         plot(t.fit_results.x_HD,t.make_gaussian_fmri_zeromean_freeY(t.fit_results.x_HD,params_GaussY(1,ns,3),params_GaussY(2,ns,3),params_GaussY(3,ns,3)),'m','LineWidth',2)
    %         hold on
    %         plot(t.fit_results.x_HD,t.boxcar_freeY(t.fit_results.x_HD,params_bin_freey(1,ns,3),params_bin_freey(2,ns,3),params_bin_freey(3,ns,3)),'b','LineWidth',2)
    %         hold on;
    %             legend('rating (M)','rating data','Gauss','binary')
    %         box off
    %         axis square
    %         set(gca,'XTick',[0 180],'XTickLabel',{'CS+','CS-'});
    %         title(sprintf('Sub No %02d',ns))
    %         set(gca,'FontSize',14);
    % set(gcf,'color','w')
    %     %% all subs
    %     fg = figure;
    %     fg.Position = [0 769 1920 1124];
    %
    %     sc = 0;
    %     for ns=1:40
    %         sc = sc+1;
    %         subplot(5,8,sc)
    %         t = Tuning(Subject(subs(ns)).get_rating(4));
    %         t.visualization = 0;
    %         t.SingleSubjectFit(3);
    %         b = bar(-135:45:180,t.y_mean);
    %         set(b,'FaceAlpha',.3,'EdgeColor','none')
    %         hold on
    %         plot(t.x,t.y,'o','MarkerFaceColor',[.8 .8 .8])
    %         plot(t.fit_results.x_HD,t.make_gaussian_fmri_zeromean(t.fit_results.x_HD,params_Gauss(1,ns,3),params_Gauss(2,ns,3))+mean(t.y_mean),'r','LineWidth',2)
    %
    %         hold on
    %         plot(t.fit_results.x_HD,t.make_gaussian_fmri_zeromean_freeY(t.fit_results.x_HD,params_GaussY(1,ns,3),params_GaussY(2,ns,3),params_GaussY(3,ns,3)),'m','LineWidth',2)
    %         hold on
    %         plot(t.fit_results.x_HD,t.boxcar_freeY(t.fit_results.x_HD,params_bin_freey(1,ns,3),params_bin_freey(2,ns,3),params_bin_freey(3,ns,3)),'b','LineWidth',2)
    %         hold on;
    % %             legend('rating (M)','rating data','Gauss','Gauss free Y','binary free_y')
    %         box off
    %         axis square
    %         set(gca,'XTick',[0 180],'XTickLabel',{'CS+','CS-'});
    %         title(sprintf('Sub No %02d',ns))
    %     end
    %     set(gcf,'color','w');
    %     saveas(gcf,[cd '\singlesub_GaussBox_sub1-40.svg'],'svg')
    %% SCR.
    p = Project;
    subs = FPSA_FearGen('get_subjects');
    scrsubs        = subs(ismember(subs,p.subjects(p.subjects_scr)));
    path2modelfits = sprintf('%sdata/midlevel/SCR_binary2Gauss_N%d_fits_3_14_withparams.mat',path_project,length(scrsubs));
    
    scrpath        = sprintf('%sdata/midlevel/SCR_N%d.mat',path_project,length(scrsubs));
    load(scrpath);
    ind_run = {1:8,10:17,19:26};
    %     if~exist(path2modelfits) || force == 1
    
    for sc = 1:length(scrsubs)
        
        s = Subject(scrsubs(sc));
        pc = 0;
        for ph = [1 3]
            pc = pc+1;
            data.y = out.y(sc,ind_run{ph});
            data.x = -135:45:180;
            data.ids = sc;
            t = Tuning(data);
            t.visualization = 0;
            t.SingleSubjectFit(3);
            params_Gauss_scr(:,sc,pc) = t.fit_results.params;
            LL_Gauss_scr(sc,pc) = t.fit_results.Likelihood;
            LL_null_scr(sc,pc)  = t.fit_results.null_Likelihood;
            %                 t.SingleSubjectFit(12);
            %                 LL_bin_freey_scr(sc,pc)   = t.fit_results.Likelihood;
            %                 params_bin_freey_scr(:,sc,pc) = t.fit_results.params;
            t.SingleSubjectFit(14);
            LL_bin_freey14_scr(sc,pc)   = t.fit_results.Likelihood;
            params_bin_freey14_scr(:,sc,pc) = t.fit_results.params;
        end
    end
    %         save(path2modelfits,'LL_Gauss_scr','LL_null_scr','LL_bin_freey_scr','params_Gauss_scr','params_bin_freey_scr','params_bin_freey_unr_scr','LL_bin_freey_unr_scr')
    
    save(path2modelfits,'LL_Gauss_scr','LL_null_scr','LL_bin_freey14_scr','params_Gauss_scr','params_bin_freey14_scr')
    %     else
    %         load(path2modelfits)
    %     end
    %     param_G = 2;
    %     param_B = 3;
    %     aic_gauss_scr     =  2*LL_Gauss_scr + 2*param_G; %number of params
    %     aic_bin_freey_scr =  2*LL_bin_freey_scr + 2*param_B;
    %     gausswins_freeY_scr =(aic_gauss_scr<aic_bin_freey_scr);
    %     BinomPval_GaussfreeY_scr  = binopdf(sum(gausswins_freeY_scr),length(scrsubs),.5); %.5 for chance level.
    
    
    %
    %     figure;
    %     for ns =1:63
    %         subplot(7,9,ns)
    %      b = bar(-135:45:180,out.y(ns,19:26));
    %         set(b,'FaceAlpha',.3,'EdgeColor','none')
    %         hold on
    %         plot(t.fit_results.x_HD,t.make_gaussian_fmri_zeromean(t.fit_results.x_HD,params_Gauss_scr(1,ns,2),params_Gauss_scr(2,ns,2))+mean(out.y(ns,19:26)),'r','LineWidth',2)
    %
    %         hold on
    %         plot(t.fit_results.x_HD,t.boxcar_freeY(t.fit_results.x_HD,params_bin_freey_scr(1,ns,2),params_bin_freey_scr(2,ns,2),params_bin_freey_scr(3,ns,2)),'b','LineWidth',2)
    %         hold on;
    % %             legend('rating (M)','rating data','Gauss','Gauss free Y','binary free_y')
    %         box off
    %         axis square
    %         set(gca,'XTick',[0 180],'XTickLabel',{'CS+','CS-'});
    %         title(sprintf('Sub No %02d',ns))
    %     end
    
    %% Rating %%LK clean up here
    load('C:\Users\Lea\Documents\Experiments\project_FPSA_FearGen\data\midlevel\Ratings_binary2Gauss_N74_fits_3_14.mat')
    param_G =2;
    param_B =3;
    aic_gauss     =  2*LL_Gauss + 2*param_G; %number of params
    aic_bin_freey =  2*LL_bin_freey14 + 2*param_B;
    
    gausswins_freeY =sum((aic_gauss <aic_bin_freey));
    BinomPval_GaussfreeY  = binopdf(gausswins_freeY,length(LL_Gauss),.5);
    fprintf('RATE: Gauss wins in %d/%d/%d out of %d subs (p = %04.3f,%04.3f,%04.3f)',gausswins_freeY(1),gausswins_freeY(2),gausswins_freeY(3),length(LL_Gauss),BinomPval_GaussfreeY(1),BinomPval_GaussfreeY(2),BinomPval_GaussfreeY(3));
    %% SCR
    param_G =2;
    param_B =3;
    
    load('C:\Users\Lea\Documents\Experiments\project_FPSA_FearGen\data\midlevel\SCR_binary2Gauss_N63_fits_3_14.mat')
    aic_gauss_scr     =  2*LL_Gauss(:,[1 3]) + 2*param_G; %number of params
    aic_bin_freey_scr =  2*LL_bin_freey14(:,[1 3]) + 2*param_B;
    
    gausswins_freeY_scr =sum((aic_gauss_scr<aic_bin_freey_scr));
    BinomPval_GaussfreeY_scr  = binopdf(gausswins_freeY_scr,length(LL_Gauss),.5);
    fprintf('SCR: Gauss wins in %d/%d out of %d subs (p = %04.3f,%04.3f)',gausswins_freeY_scr(1),gausswins_freeY_scr(2),length(LL_Gauss),BinomPval_GaussfreeY_scr(1),BinomPval_GaussfreeY_scr(2));
    
elseif strcmp(varargin{1},'get_path_project');
    varargout{1} = path_project;
    
else
    fprintf('No action with this name %s is present...\n',varargin{1});
    varargout ={};
    return;
    
end

%% References:
% (1) https://github.com/selimonat/fancycarp.git
% (2) https://github.com/selimonat/globalfunctions.git
% (3) An extensive dataset of eye movements during viewing of complex images
% Nature Scientific Data, 2017
% Niklas Wilming, Selim Onat, Jos? P. Ossand?n, Alper A??k, Tim C.
% Kietzmann, Kai Kaspar, Ricardo R. Gameiro, Alexandra Vormberg & Peter K?nig
% (4) Comparing the similarity and spatial structure of neural
% representations: A pattern-component model
% Diedrichsen Jm et al.
% NeuroI