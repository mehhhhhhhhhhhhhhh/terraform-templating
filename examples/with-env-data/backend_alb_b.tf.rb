vpc = r.aws_vpc.main
subnet1 = r.aws_subnet.public_1
subnet2 = r.aws_subnet.public_2

sg = r.aws_security_group.backend_elb

lb = r :aws_lb, :backend_alb_b do
	name "#{Environment.tag_name}-backend-alb-b"
	subnets [subnet1.id, subnet2.id]
	internal true
	security_groups [sg.id]
	idle_timeout 30

	if Environment['export_alb_access_logs']
		access_logs ({
			bucket: r.aws_s3_bucket['alb-logs'].id,
			enabled: true,
		})
	end
end

r :aws_route53_record, :backend_lb_b do
	zone_id r.aws_route53_zone.internal.zone_id
	name "backend-lb-b.#{Environment.domain}"
	type 'CNAME'
	ttl '60'
	records [lb.dns_name]
end

BackendStack.each do |backend_service|
	abbrev_name = backend_service['abbrev_name']

	tg = r :aws_lb_target_group, "backend_alb_target_#{abbrev_name}_b" do
		name "#{Environment.tag_name}-lb-#{abbrev_name}-b"
		port backend_service['port']
		protocol 'HTTP'
		vpc_id vpc.id
		deregistration_delay 30

		health_check ({
			matcher: (backend_service['annoying_inconsistent_health_status'] || '200'),
			healthy_threshold: 2,
			unhealthy_threshold: 2,
			interval: 10,
			timeout: 8,
			path: (backend_service['annoying_inconsistent_health_path'] || '/manage/health'),
		})
	end

	r :aws_lb_listener, "backend_alb_listener_#{abbrev_name}_b" do
		load_balancer_arn lb.arn
		port backend_service['port']
		protocol 'HTTP'

		default_action ({
			target_group_arn: tg.arn,
			type: 'forward',
		})
	end

end
