function exemplar_display_result_kitti

cls = 'car';
threshold = -20;
is_save = 0;
threshold_overlap = 0.6;
is_train = 0;
result_dir = 'kitti_test_acf_3d_167_flip';
name = '3d_ap_167_combined';
% is_train = 1;
% result_dir = 'kitti_train_ap_125';
% name = '3d_aps_125_combined';

% read detection results
filename = sprintf('%s/%s_%s_test.mat', result_dir, cls, name);
object = load(filename);
dets = object.dets;
fprintf('load detection done\n');

% read ids of validation images
object = load('kitti_ids_new.mat');
if is_train
    ids = object.ids_val;
else
    ids = object.ids_test;
end
N = numel(ids);

% KITTI path
exemplar_globals;
root_dir = KITTIroot;
if is_train
    data_set = 'training';
else
    data_set = 'testing';
end
cam = 2;
image_dir = fullfile(root_dir, [data_set '/image_' num2str(cam)]);
label_dir = fullfile(root_dir, [data_set '/label_' num2str(cam)]);

% load data
if is_train
    filename = fullfile(SLMroot, 'KITTI/data.mat');
else
    filename = fullfile(SLMroot, 'KITTI/data_kitti.mat');
end
object = load(filename);
data = object.data;

hf = figure(1);
cmap = colormap(summer);
for i = 1859:N
    img_idx = ids(i);
    disp(img_idx);
    
    % read ground truth bounding box
    if is_train
        objects = readLabels(label_dir, img_idx);
        clsinds = strmatch(cls, lower({objects(:).type}), 'exact');
        n = numel(clsinds);
        bbox_gt = zeros(n, 4); 
        for j = 1:n
            bbox_gt(j,:) = [objects(clsinds(j)).x1 objects(clsinds(j)).y1 ...
                objects(clsinds(j)).x2 objects(clsinds(j)).y2];     
        end
        flags_gt = zeros(n, 1);
    end
    
    % get predicted bounding box
    det = dets{i};
    if isempty(det) == 1
        fprintf('no detection for image %d\n', img_idx);
        continue;
    end
    if max(det(:,6)) < threshold
        fprintf('maximum score %.2f is smaller than threshold\n', max(det(:,6)));
        continue;
    end
    if isempty(det) == 0
        I = nms_new(det, threshold_overlap);
        det = det(I, :);
        I = det(:,6) >= threshold;
        det = det(I,:);
        height = det(:,4) - det(:,2);
        [~, I] = sort(height);
        det = det(I,:);        
    end
    num = size(det, 1);
    
    % for each predicted bounding box
    if is_train
        flags_pr = zeros(num, 1);
        for j = 1:num
            bbox_pr = det(j, 1:4);  

            % compute box overlap
            if isempty(bbox_gt) == 0
                o = boxoverlap(bbox_gt, bbox_pr);
                [maxo, index] = max(o);
                if maxo >= 0.6 && flags_gt(index) == 0
                    flags_pr(j) = 1;
                    flags_gt(index) = 1;
                end
            end
        end
    end
    
    file_img = sprintf('%s/%06d.png', image_dir, img_idx);
    I = imread(file_img);
    
    % show all the detections
%     figure(1);
%     imshow(I);
%     hold on;
%     
%     for k = 1:size(dets{i},1)
%         bbox_pr = dets{i}(k,1:4);
%         bbox_draw = [bbox_pr(1), bbox_pr(2), bbox_pr(3)-bbox_pr(1), bbox_pr(4)-bbox_pr(2)];
%         rectangle('Position', bbox_draw, 'EdgeColor', 'g', 'LineWidth', 2);
%     end
%     hold off;


    % add pattern
    for k = 1:num
        if det(k,6) > threshold
            bbox_pr = det(k,1:4);
            bbox = zeros(1,4);
            bbox(1) = max(1, floor(bbox_pr(1)));
            bbox(2) = max(1, floor(bbox_pr(2)));
            bbox(3) = min(size(I,2), floor(bbox_pr(3)));
            bbox(4) = min(size(I,1), floor(bbox_pr(4)));
            w = bbox(3) - bbox(1) + 1;
            h = bbox(4) - bbox(2) + 1;

            % apply the 2D occlusion mask to the bounding box
            % check if truncated pattern
            cid = det(k,5);
            pattern = data.pattern{cid};                
            index = find(pattern == 1);
            if data.truncation(cid) > 0 && isempty(index) == 0
%                 [y, x] = ind2sub(size(pattern), index);                
%                 pattern = pattern(min(y):max(y), min(x):max(x));
                
                [y, x] = ind2sub(size(pattern), index);
                cx = size(pattern, 2)/2;
                cy = size(pattern, 1)/2;
                width = size(pattern, 2);
                height = size(pattern, 1);                 
                pattern = pattern(min(y):max(y), min(x):max(x));

                % find the object center
                sx = w / size(pattern, 2);
                sy = h / size(pattern, 1);
                tx = bbox(1) - sx*min(x);
                ty = bbox(2) - sy*min(y);
                cx = sx * cx + tx;
                cy = sy * cy + ty;
                width = sx * width;
                height = sy * height;
                bbox_pr = round([cx-width/2 cy-height/2 cx+width/2 cy+height/2]);
                width = bbox_pr(3) - bbox_pr(1) + 1;
                height = bbox_pr(4) - bbox_pr(2) + 1;
                
                pattern = imresize(data.pattern{cid}, [height width], 'nearest');
                
                bbox = zeros(1,4);
                bbox(1) = max(1, floor(bbox_pr(1)));
                start_x = bbox(1) - floor(bbox_pr(1)) + 1;
                bbox(2) = max(1, floor(bbox_pr(2)));
                start_y = bbox(2) - floor(bbox_pr(2)) + 1;
                bbox(3) = min(size(I,2), floor(bbox_pr(3)));
                bbox(4) = min(size(I,1), floor(bbox_pr(4)));
                w = bbox(3) - bbox(1) + 1;
                h = bbox(4) - bbox(2) + 1;
                pattern = pattern(start_y:start_y+h-1, start_x:start_x+w-1);
            else
                pattern = imresize(pattern, [h w], 'nearest');
            end
            
            % build the pattern in the image
            height = size(I,1);
            width = size(I,2);
            P = uint8(zeros(height, width));
            x = bbox(1);
            y = bbox(2);
            index_y = y:min(y+h-1, height);
            index_x = x:min(x+w-1, width);
            P(index_y, index_x) = pattern(1:numel(index_y), 1:numel(index_x));
            
            % show occluded region
            im = create_occlusion_image(pattern);
            x = bbox(1);
            y = bbox(2);
            Isub = I(y:y+h-1, x:x+w-1, :);
            index = im == 255;
            im(index) = Isub(index);
            I(y:y+h-1, x:x+w-1, :) = uint8(0.1*Isub + 0.9*im);             
            
            % show segments
            index_color = 1 + floor((k-1) * size(cmap,1) / num);
            if is_train
                if flags_pr(k)
                    dispColor = 255*cmap(index_color,:);
                else
                    dispColor = [255 0 0];
                end
            else
                dispColor = 255*cmap(index_color,:);
            end
            scale = round(max(size(I))/400);            
            [gx, gy] = gradient(double(P));
            g = gx.^2 + gy.^2;
            g = conv2(g, ones(scale), 'same');
            edgepix = find(g > 0);
            npix = numel(P);
            for b = 1:3
                I((b-1)*npix+edgepix) = dispColor(b);
            end
        end
    end
    
    imshow(I);
    hold on;
    for k = 1:num
        if det(k,6) > threshold
            % get predicted bounding box
            bbox_pr = det(k,1:4);
            disp(det(k,5));
%             bbox_draw = [bbox_pr(1), bbox_pr(2), bbox_pr(3)-bbox_pr(1), bbox_pr(4)-bbox_pr(2)];
%             if is_train
%                 if flags_pr(k)
%                     rectangle('Position', bbox_draw, 'EdgeColor', 'g', 'LineWidth', 2);
%                 else
%                     rectangle('Position', bbox_draw, 'EdgeColor', 'r', 'LineWidth', 2);
%                 end
%             else
%                 rectangle('Position', bbox_draw, 'EdgeColor', 'g', 'LineWidth', 2);
%             end
            cid = det(k,5);
%             cind = find(centers == cid);
            s = sprintf('%d', cid);
%             text(bbox_pr(3), bbox_pr(4), s, 'FontSize', 8, 'BackgroundColor', 'c');
        end
    end
    
%     if is_train
%         for k = 1:n
%             if flags_gt(k) == 0
%                 bbox = bbox_gt(k,1:4);
%                 bbox_draw = [bbox(1), bbox(2), bbox(3)-bbox(1), bbox(4)-bbox(2)];
%                 rectangle('Position', bbox_draw, 'EdgeColor', 'y', 'LineWidth', 2);
%             end
%         end
%     end
    hold off;
    
    if is_save
        filename = fullfile('result_images', sprintf('%06d.png', img_idx));
        saveas(hf, filename);
    else
        pause;
    end
end


function im = create_occlusion_image(pattern)

% 2D occlusion mask
im = 255*ones(size(pattern,1), size(pattern,2), 3);
color = [255 0 0];
for j = 1:3
    tmp = im(:,:,j);
    tmp(pattern == 2) = color(j);
    im(:,:,j) = tmp;
end
color = [0 255 255];
for j = 1:3
    tmp = im(:,:,j);
    tmp(pattern == 3) = color(j);
    im(:,:,j) = tmp;
end
im = uint8(im);  