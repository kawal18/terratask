provider "aws"{

profile= "kawal"
region = "ap-south-1"

}

resource "aws_instance" "myin" {

ami         = "ami-052c08d70def0ac62"
instance_type = "t2.micro"
key_name     =  "dockerkey"
 security_groups = [ "launch-wizard-2" ]


 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/MINNY/Downloads/dockerkey.pem")
    host     = aws_instance.myin.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
}

  tags = {
    Name = "myos1"
  }

}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.myin.availability_zone
  size              = 1
  tags = {
    Name = "esb1"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.myin.id}"
  force_detach = true
}




resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/MINNY/Downloads/dockerkey.pem")
    host     = aws_instance.myin.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/kawal18/terratask.git /var/www/html/"
    ]
  }
}





resource "aws_s3_bucket" "kawal18899" {
depends_on = [
null_resource.nullremote3,
]
    bucket = "kawal18899"
    acl    = "public-read"
    force_destroy = true
     

    tags = {
	Name    = "kawal18899"
	Environment = "Dev"
    }
    versioning {
	enabled =true
    }
}

locals{

s3_origin_id = aws_s3_bucket.kawal18899.bucket

}

//Upload inamge to S3

resource "aws_s3_bucket_object" "teraimage"{
   

depends_on = [

aws_s3_bucket.kawal18899
]

bucket = aws_s3_bucket.kawal18899.id
key = "terrafrom_pic.jpg"
source = "C:/Users/MINNY/Desktop/terrafrom_pic.jpg"
acl    = "public-read"
content_type = "image/jpg"



}

resource "aws_cloudfront_distribution" "mycf" {
    origin {
        domain_name = aws_s3_bucket.kawal18899.bucket_regional_domain_name
        origin_id = local.s3_origin_id 


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id 


        # Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"

      }
    }


    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}


resource "null_resource" "cloud_url"  {

depends_on = [
    aws_cloudfront_distribution.mycf,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/MINNY/Downloads/dockerkey.pem")
    host     = aws_instance.myin.public_ip
  }

provisioner "remote-exec" {
    inline = [

" echo\"<img src ='https://${aws_cloudfront_distribution.mycf.domain_name}/terrafrom_pic.jpg' width = '400' length = '400'>\" | sudo tee -a /var/www/html/index.php", "sudo systemctl start httpd"

]
}
}






