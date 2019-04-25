module "random_name" {
  source = "../random_pet"
}

resource "aws_key_pair" "my_key" {
  key_name   = "key-${module.random_name.name}"
  public_key = "${var.public_key}"
}

resource "aws_instance" "nginx_instance" {
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"

  availability_zone = "${var.availability_zone}"

  subnet_id              = "${var.subnet_id}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]
  key_name               = "${aws_key_pair.my_key.id}"

  tags {
    Name = "${var.frontend_region}-${var.dc}-${module.random_name.name}-frontend"
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.root}/scripts/certbot.sh",
      "${path.root}/scripts/cron_create.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
    }
  }
}

resource "null_resource" "nginx_config" {
  # Changes to any server instance of the nomad cluster requires re-provisioning
  triggers = {
    backend_instance_ips   = "${jsonencode(var.backend_private_ips)}"
    cloudflare_record_ip   = "${cloudflare_record.nomad_frontend.value}"
    cloudflare_record_name = "${cloudflare_record.nomad_frontend.name}"
  }

  depends_on = ["aws_instance.nginx_instance"]

  # script can run on every nomad server instance change
  connection {
    type        = "ssh"
    host        = "${aws_instance.nginx_instance.public_ip}"
    user        = "ubuntu"
    private_key = "${file("~/.ssh/id_rsa")}"
  }

  provisioner "file" {
    # script called with private_ips of nomad backend servers
    source      = "${path.root}/scripts/nginx.sh"
    destination = "/tmp/nginx.sh"
  }

  provisioner "remote-exec" {
    # script called with private_ips of nomad backend servers
    inline = [
      "chmod +x /tmp/nginx.sh",
      "sudo /tmp/nginx.sh",
      "export IN=${replace(jsonencode(var.backend_private_ips), ",", "")}",                           #search for and remove commas
      "OUT=$(echo $IN | tr -d '[]')",                                                                 #remove square brackets
      "export OUT",
      "sudo -E bash -c 'echo upstream nomad_backend { $OUT } >> /etc/nginx/sites-available/default'",
      "sudo systemctl start nginx.service",
      "sudo rm -rf /tmp/*",
    ]
  }
}

# Create a record
resource "cloudflare_record" "nomad_frontend" {
  domain = "${var.cloudflare_zone}"
  name   = "${var.subdomain_name}"
  value  = "${aws_instance.nginx_instance.public_ip}"
  type   = "A"
  ttl    = 3600
}

resource "null_resource" "certbot" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cloudflare_record = "${cloudflare_record.nomad_frontend.value}"
    nginx_config      = "${null_resource.nginx_config.id}"
  }

  depends_on = ["cloudflare_record.nomad_frontend", "null_resource.nginx_config"]

  # certbot script can run on every instance ip change
  connection {
    type        = "ssh"
    host        = "${aws_instance.nginx_instance.public_ip}"
    user        = "ubuntu"
    private_key = "${file("~/.ssh/id_rsa")}"
  }

  provisioner "remote-exec" {
    # certbot script called with public_ip of frontend server
    inline = [
      "sudo certbot --nginx --non-interactive --agree-tos -m ${var.cloudflare_email} -d ${var.subdomain_name}.${var.cloudflare_zone} --redirect",
    ]
  }
}
