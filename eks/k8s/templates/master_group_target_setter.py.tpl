import boto3
import dns
import dns.resolver

client = boto3.client('elbv2')

cluster_endpoint="${cluster_endpoint}"
newdns_result = dns.resolver.query(cluster_endpoint.replace('https://', ''), 'A')

response = client.describe_target_groups(
    TargetGroupArns=[
        '${target_group_arn}',
    ],
    PageSize=100
)
print(response)

for ipval in newdns_result:
  print('IP', ipval.to_text())
  response = client.register_targets(
      TargetGroupArn='${target_group_arn}',
      Targets=[
          {
              'Id': ipval.to_text(),
          },
      ]
  )
