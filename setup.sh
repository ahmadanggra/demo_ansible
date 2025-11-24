#!/usr/bin/bash

# Install necessary application
sudo dnf update -y
sudo dnf install ansible-core python3-pip git -y
pip install ansible-pylibssh

# Create ansible directory
cd ~
mkdir ansible_demo > /dev/null 2>&1; cd ansible_demo > /dev/null 2>&1
mkdir -p collections group_vars/arista host_vars/veos1 > /dev/null 2>&1

# For example config
# ansible-config init --disable > sample.cfg

# Generate ansible.cfg
if [ ! -f "ansible.cfg" ]; then
        touch ansible.cfg
else
        # Empty ansible.cfg
        echo "" > ansible.cfg
fi
echo "[defaults]" >> ansible.cfg
echo "collections_path= ~/.ansible/collections:/usr/share/ansible/collections:./collections" >> ansible.cfg
echo "inventory=inventory" >> ansible.cfg
echo "host_key_checking=False" >> ansible.cfg
echo "collections_on_ansible_version_mismatch=ignore" >> ansible.cfg

# Generate inventory
if [ ! -f "inventory" ]; then
        touch inventory
else
        # Empty inventory
        echo "" > inventory
fi
echo "[arista]" >> inventory
echo "veos1 ansible_host=192.168.50.110" >> inventory

# Generate group_vars and host_vars
if [ ! -f "group_vars/arista/all.yml" ]; then
        touch group_vars/arista/all.yml
else
        # Empty inventory
        echo "" > group_vars/arista/all.yml
fi
echo "---" >> group_vars/arista/all.yml
echo "ansible_connection: ansible.netcommon.network_cli" >> group_vars/arista/all.yml
echo "ansible_network_os: arista.eos.eos" >> group_vars/arista/all.yml
echo "ansible_become: true" >> group_vars/arista/all.yml
echo "ansible_become_method: enable" >> group_vars/arista/all.yml

if [ ! -f "host_vars/veos1/auth.yml" ]; then
        touch host_vars/veos1/auth.yml
else
        # Empty inventory
        echo "" > host_vars/veos1/auth.yml
fi
echo "---" >> host_vars/veos1/auth.yml
echo "ansible_user: ansible" >> host_vars/veos1/auth.yml
echo "ansible_password: C0mpn3t!" >> host_vars/veos1/auth.yml

if [ ! -f "collections/requirements.yml" ]; then
        touch collections/requirements.yml
else
        # Empty inventory
        echo "" > collections/requirements.yml
fi
echo "collections:" >> collections/requirements.yml
echo "  - name: arista.eos" >> collections/requirements.yml
echo "  - name: community.general" >> collections/requirements.yml

# Install the collection
ansible-galaxy collection install -r collections/requirements.yml -p collections --force

# Create vlan_add.yml playbook
VLAN_CONFIG=$(cat <<'EOF'
---
- name: Demo arista gather data & config
  hosts: veos1
  gather_facts: False
  tasks:
    - name: Gather fact
      arista.eos.eos_facts:
        gather_subset:
          - interfaces
    - name: Print management port IP address
      ansible.builtin.debug:
        msg: "Switch IP management: {{ ansible_facts['net_interfaces']['Management1']['ipv4']['address'] }}/{{ ansible_facts['net_interfaces']['Management1']['ipv4']['masklen'] }}"
    - name: Add vlan 10 and vlan 20
      arista.eos.eos_vlans:
        config:
          - name: factory_1
            vlan_id: 10
          - name: factory_2
            vlan_id: 20
        state: merged
    - name: Bind vlan 10 to 
      arista.eos.eos_l2_interfaces:
        config:
          - name: Ethernet1
            mode: access 
            access:
              vlan: 10
        state: merged
    - name: Config vlan 10 ip address
      arista.eos.eos_l3_interfaces:
        config:
          - name: Vlan 10
            ipv4:
              - address: 10.0.0.1/24
        state: merged
    - name: Backup config to local
      arista.eos.eos_config:
        backup: true
        backup_options:
          filename: config_add_vlan.cfg
    - name: Create checkpoint for restore
      arista.eos.eos_command:
        commands: configure checkpoint save before_change

EOF
)

VLAN_DEL=$(cat <<'EOF'
---
- name: Demo arista delete vlan config
  hosts: veos1
  gather_facts: False
  tasks:
    - name: Delete vlan 10 ip address
      arista.eos.eos_l3_interfaces:
        config:
          - name: Vlan 10
            ipv4:
              - address: 10.0.0.1/24
        state: deleted
    - name: Delete vlan 10 on eth1 
      arista.eos.eos_l2_interfaces:
        config:
          - name: Ethernet1
            mode: access 
            access:
              vlan: 10
        state: deleted
    - name: Remove vlan 10 and vlan 20
      arista.eos.eos_vlans:
        config:
          - name: factory_1
            vlan_id: 10
          - name: factory_2
            vlan_id: 20
        state: deleted
EOF
)

echo "$VLAN_CONFIG" > vlan_add.yml
echo "$VLAN_DEL" > vlan_del.yml
