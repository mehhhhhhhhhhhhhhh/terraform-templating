require 'json'

CachingOptimizedPolicyId = '658327ea-f89d-4fab-a63d-7e88639e58f6'
CachingDisabledPolicyId = '4cc15a8a-d715-48a4-82b8-cc0b614638fe'

logs_bucket = r.aws_s3_bucket.frontend_logs

cert = d :aws_acm_certificate, "www_example_com" do
	domain 'www.example.com'
	statuses ['ISSUED']
	most_recent true
end

r :aws_cloudfront_distribution, 'www_example_com' do
	enabled true
	aliases [
		'cdn.example.com',
		'www.example.com',
	]
	comment "Split www.example.com between CDN site and app ALB"
	default_cache_behavior [{
		allowed_methods: %w[GET HEAD],
		cache_policy_id: CachingOptimizedPolicyId,
		cached_methods: %w[GET HEAD],
		compress: true,
		target_origin_id: :CDN,
		viewer_protocol_policy: 'redirect-to-https',
	}]
	logging_config ({
		bucket: logs_bucket.id,
		include_cookies: false,
	})
	ordered_cache_behavior [
		*JSON.load_file(File.join(__dir__, 'app-paths.json'))['app_paths'].map {|path|
			{
				allowed_methods: %w[DELETE GET HEAD OPTIONS PATCH POST PUT],
				cache_policy_id: CachingDisabledPolicyId,
				cached_methods: %w[GET HEAD],
				compress: false,
				path_pattern: path['pattern'],
				target_origin_id: :ALB,
				viewer_protocol_policy: (path['allow_http'] ? 'allow-all' : 'redirect-to-https'),
			}
		},
		{
			allowed_methods: %w[GET HEAD],
			cache_policy_id: CachingOptimizedPolicyId,
			cached_methods: %w[GET HEAD],
			compress: true,
			path_pattern: '/client-assets/*',
			target_origin_id: 'client-assets S3',
			viewer_protocol_policy: 'redirect-to-https'
		}
	]
	origin [
		{
			origin_id: :CDN,
			custom_origin_config: [
				{
					http_port: 80,
					https_port: 443,
					origin_protocol_policy: 'https-only',
					origin_ssl_protocols: %w[TLSv1.2],
				}
			],
			domain_name: 'examplecom.sites.cdn.net',
		},
		{
			origin_id: :ALB,
			custom_origin_config: [
				{
					http_port: 80,
					https_port: 443,
					origin_protocol_policy: 'https-only',
					origin_ssl_protocols: %w[TLSv1.2],
				}
			],
			domain_name: 'alb-www-example-com-1234567890.us-west-2.elb.amazonaws.com',
		},
		{
			origin_id: 'client-assets S3',
			domain_name: 'client-assets.example.com.s3.us-east-1.amazonaws.com',
		}
	]
	price_class :PriceClass_All
	restrictions [
		{
			geo_restriction: [{
				restriction_type: :none,
			}]
		}
	]
	tags ({})
	viewer_certificate [
		{
			acm_certificate_arn: cert.arn,
			cloudfront_default_certificate: false,
			minimum_protocol_version: 'TLSv1.2_2018',
			ssl_support_method: 'sni-only',
		}
	]
	wait_for_deployment true
end
