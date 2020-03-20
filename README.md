# ceph-install
install ceph in one host

# pg current state undersized+peered
如果 副本数配置为3 
osd pool default size = 3
需要修改crushmap 

    # rules
    rule replicated_rule {
            id 0
            type replicated
            min_size 1
            max_size 10
            step take default
            step chooseleaf firstn 0 type host
            step emit
    }
    将host改为osd
    # rules
    rule replicated_rule {
            id 0
            type replicated
            min_size 1
            max_size 10
            step take default
            step chooseleaf firstn 0 type host
            step emit
    }
    
    
 # 修改crushmap步骤
    ceph osd  getcrushmap -o old.map
    crushtool -d old.map -o old.txt 
    crushtool -c new.txt -o new.map
    ceph osd setcrushmap -i new.map
