/***********************************************************************
  Copyright (C) 2019 Hironori Fujimoto

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
 
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
***********************************************************************/

#include "sgm_gpu_nodelet.h"

#include <pluginlib/class_list_macros.h>
PLUGINLIB_EXPORT_CLASS(sgm_gpu::SgmGpuNodelet, nodelet::Nodelet);

#include <cv_bridge/cv_bridge.h>
#include <image_geometry/stereo_camera_model.h>
#include <image_transport/camera_common.h>
#include <sensor_msgs/image_encodings.h>
#include <stereo_msgs/DisparityImage.h>

#include <opencv2/opencv.hpp>

#include "disparity_method.h"

namespace sgm_gpu {

void SgmGpuNodelet::onInit()
{
  ros::NodeHandle &node_handle = getNodeHandle();
  ros::NodeHandle &private_node_handle = getPrivateNodeHandle();

  // Get parameters used in SGM algorithm
  // Default value from https://github.com/dhernandez0/sgm/blob/master/README.md
  sgm_p1_ = static_cast<uint8_t>(private_node_handle.param("p1", 6));
  sgm_p2_ = static_cast<uint8_t>(private_node_handle.param("p2", 96));

  image_transport_.reset(new image_transport::ImageTransport(node_handle));

  disparity_pub_ = private_node_handle.advertise<stereo_msgs::DisparityImage>("disparity", 1);

  // Subscribe left and right Image topic
  std::string left_base_topic = node_handle.resolveName("left_image");
  std::string right_base_topic = node_handle.resolveName("right_image");
  left_image_sub_.subscribe(*image_transport_, left_base_topic, 10);
  right_image_sub_.subscribe(*image_transport_, right_base_topic, 10);

  // Find CameraInfo topic from corresponded Image topic and subscribe it
  std::string left_info_topic = image_transport::getCameraInfoTopic(left_base_topic);
  std::string right_info_topic = image_transport::getCameraInfoTopic(right_base_topic);
  left_info_sub_.subscribe(node_handle, left_info_topic, 10);
  right_info_sub_.subscribe(node_handle, right_info_topic, 10);

  stereo_synchronizer_.reset(new StereoSynchronizer(left_image_sub_, right_image_sub_, left_info_sub_, right_info_sub_, 10));
  stereo_synchronizer_->registerCallback(&SgmGpuNodelet::stereoCallback, this);

  init_disparity_method(sgm_p1_, sgm_p2_);
}

void SgmGpuNodelet::stereoCallback(const sensor_msgs::ImageConstPtr &left_image_msg, const sensor_msgs::ImageConstPtr &right_image_msg, const sensor_msgs::CameraInfoConstPtr &left_info_msg, const sensor_msgs::CameraInfoConstPtr &right_info_msg)
{
  if (disparity_pub_.getNumSubscribers() == 0)
    return;

  // Even if image has 3 channels(RGB), cv_bridge convert it to greyscale
  cv_bridge::CvImagePtr cv_left_image = cv_bridge::toCvCopy(left_image_msg, sensor_msgs::image_encodings::MONO8);
  cv_bridge::CvImagePtr cv_right_image = cv_bridge::toCvCopy(right_image_msg, sensor_msgs::image_encodings::MONO8);

  if (cv_left_image->image.rows != cv_right_image->image.rows || cv_left_image->image.cols != cv_right_image->image.cols)
  {
    NODELET_INFO("Image dimension of left and right are not same");
    return;
  }

  if (cv_left_image->image.rows % 4 != 0 || cv_left_image->image.cols % 4 != 0)
  {
    NODELET_INFO("Image width and height must be divisible by 4");
    return;
  }

  float elapsed_time_ms;
  cv::Mat disparity_8u = compute_disparity_method(cv_left_image->image, cv_right_image->image, &elapsed_time_ms);

  NODELET_INFO("Elapsed time: %f [ms]", elapsed_time_ms);

  cv::Mat disparity_32f;
  disparity_8u.convertTo(disparity_32f, CV_32F);

  stereo_msgs::DisparityImage disparity_msg;
  disparity_msg.header = left_image_msg->header;

  cv_bridge::CvImage disparity_converter(left_image_msg->header, sensor_msgs::image_encodings::TYPE_32FC1, disparity_32f);
  disparity_converter.toImageMsg(disparity_msg.image);

  image_geometry::StereoCameraModel stereo_model;
  stereo_model.fromCameraInfo(left_info_msg, right_info_msg);
  disparity_msg.f = stereo_model.left().fx();
  disparity_msg.T = stereo_model.baseline();

  disparity_msg.min_disparity = 0.0;
  disparity_msg.max_disparity = 128.0;
  
  disparity_msg.delta_d = 1.0;

  disparity_pub_.publish(disparity_msg);
}

} // namespace sgm_gpu
