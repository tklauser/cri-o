#!/usr/bin/env bats

load helpers

@test "Check for valid pod netns CIDR" {
	start_crio
	run crioctl pod run --config "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	check_pod_cidr $pod_id

	cleanup_pods
	stop_crio
}

@test "Ping pod from the host" {
	start_crio
	run crioctl pod run --config "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	ping_pod $pod_id

	cleanup_pods
	stop_crio
}

@test "Ping pod from another pod" {
	start_crio
	run crioctl pod run --config "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod1_id="$output"

	temp_sandbox_conf cni_test

	run crioctl pod run --config "$TESTDIR"/sandbox_config_cni_test.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod2_id="$output"

	ping_pod_from_pod $pod1_id $pod2_id
	[ "$status" -eq 0 ]

	ping_pod_from_pod $pod2_id $pod1_id
	[ "$status" -eq 0 ]

	cleanup_pods
	stop_crio
}

@test "Ensure correct CNI plugin namespace/name/container-id arguments" {
	start_crio "" "" "" "prepare_plugin_test_args_network_conf"
	run crioctl pod run --config "$TESTDATA"/sandbox_config.json
	[ "$status" -eq 0 ]

	. /tmp/plugin_test_args.out

	[ "$FOUND_CNI_CONTAINERID" != "redhat.test.crio" ]
	[ "$FOUND_CNI_CONTAINERID" != "podsandbox1" ]
	[ "$FOUND_K8S_POD_NAMESPACE" = "redhat.test.crio" ]
	[ "$FOUND_K8S_POD_NAME" = "podsandbox1" ]

	cleanup_pods
	stop_crio
}

@test "Connect to pod hostport from the host" {
	start_crio
	run crioctl pod run --config "$TESTDATA"/sandbox_config_hostport.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	get_host_ip
	echo $host_ip

	run crioctl ctr create --config "$TESTDATA"/container_config_hostport.json --pod "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crioctl ctr start --id "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run nc -w 5 $host_ip 4888
	echo "$output"
	[ "$output" = "crioctl_host" ]
	[ "$status" -eq 0 ]
	run crioctl ctr stop --id "$ctr_id"
	echo "$output"
	cleanup_pods

	stop_crio
}
