# A ROS package of Semi-Global Matching on the GPU

`sgm_gpu` is a ROS package which contains a nodelet based on [Semi-Global Matching on the GPU by D. Hernandez-Juarez](https://github.com/dhernandez0/sgm) .

Visualized result:

![Result](images/sgm_sample.png)

## Prerequisite

- [ROS Melodic Morenia](http://wiki.ros.org/melodic)
- [CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit)

## Build

```
$ cd <YourCatkinWorkspace>/src
$ git clone https://github.com/ActiveIntelligentSystemsLab/sgm_gpu_ros.git
$ cd ..
$ catkin_make
```

## Run 

```
$ rosrun nodelet nodelet standalone sgm_gpu/sgm_gpu_nodelet left_image:=<YourLeftImageTopic> right_image:=<YourRightImageTopic>
```

You can see result by [disparity_visualize](https://github.com/ActiveIntelligentSystemsLab/disparity_visualize) .

## sgm_gpu/sgm_gpu_nodelet

A nodelet calculate disparity from stereo image topic.

### Subscribed topics

- `left_image` ([sensor_msgs/Image](http://docs.ros.org/api/sensor_msgs/html/msg/Image.html))
  
  Rectified image topic from left camera.
  Should be remapped.

- `right_image` ([sensor_msgs/Image](http://docs.ros.org/api/sensor_msgs/html/msg/Image.html))

  Rectified image topic from right camera. Should be remapped.

- `<base topic of left_image>/camera_info` ([sensor_msgs/CameraInfo](http://docs.ros.org/api/sensor_msgs/html/msg/CameraInfo.html))

  Subscribed automatically based on topic of left_image.

- `<base topic of right_image>/camera_info` ([sensor_msgs/CameraInfo](http://docs.ros.org/api/sensor_msgs/html/msg/CameraInfo.html))

  Subscribed automatically based on topic of right_image.

### Published topic

- `~disparity` ([stereo_msgs/DisparityImage](http://docs.ros.org/api/stereo_msgs/html/msg/DisparityImage.html))

  Disparity image computed by SGM

### Parameters

- `~p1` (int)

  Parameter used in SGM algorithm.
  See [SGM on GPU papar](https://www.sciencedirect.com/science/article/pii/S1877050916306561) and [SGM paper](https://ieeexplore.ieee.org/document/4359315) .

  Default value is `6` from [SGM on GPU](https://github.com/dhernandez0/sgm) .

- `~p2` (int) 

  Parameter used in SGM algorithm.
  See [SGM on GPU papar](https://www.sciencedirect.com/science/article/pii/S1877050916306561) and [SGM paper](https://ieeexplore.ieee.org/document/4359315) .

  Default value is `96` from [SGM on GPU](https://github.com/dhernandez0/sgm) .

### Limitations

- Disparity range is `[0, 127]`
- Image width and height must be a divisible by 4
