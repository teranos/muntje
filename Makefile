# Every tofu command goes through here, the q.sbvh.nl shape. Nothing
# else lives in this file.

TOFU := cd infra && tofu

.PHONY: init plan apply output fmt

init:
	$(TOFU) init

plan:
	$(TOFU) plan

apply:
	$(TOFU) apply -auto-approve

output:
	$(TOFU) output

fmt:
	$(TOFU) fmt
