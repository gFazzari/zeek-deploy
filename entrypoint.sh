#!/bin/bash
PREFIX=/usr/local/zeek
SPAN_IFACES=$(grep "$NODE_NAME" /mappings/node-iface.map | awk '{print $2}')
RAFIKI_CORES=${RAFIKI_CORES:=4}
PROCS=$(seq -s ',' 0 $((${RAFIKI_CORES} - 1 )))
CLUSTER_ID=49

IFS='-'
for iface in $SPAN_IFACES; do

  IFACES_CONF=$IFACES_CONF$(cat << EOF

[worker-$iface]
type=worker
host=localhost
interface=af_packet::$iface
lb_method=custom
lb_procs=$RAFIKI_CORES
pin_cpus=$PROCS
af_packet_fanout_id=$CLUSTER_ID

EOF
  )
  CLUSTER_ID=$(( CLUSTER_ID - 1 ))
  
#  ip link set "$iface" up
#  ip link set dev "$iface" promisc on
#  ethtool -K "$iface" tx off rx off gso off tso off gro off lro off 2> /dev/null
done
sed "s/{IFACES_CONF}/${IFACES_CONF//$'\n'/\\n}/g" /conf/node.cfg > $PREFIX/etc/node.cfg

IFS=''
zkg autoconfig --force
find /conf/ -name "*.cfg" -type f ! -name "node.cfg" -exec cp "{}" $PREFIX/etc/ \;

while read p; do
  echo "Installing plugin $p..."
  zkg install --skiptests --force $p 2> /dev/null
done </plugins/plugins.cfg

cp /local/local.zeek $PREFIX/share/zeek/site/local.zeek
mkdir -p $PREFIX/share/zeek/site/cybergon-scripts/
find /scripts/ -type f -name '*.zeek' -exec cp {} $PREFIX/share/zeek/site/cybergon-scripts/ \;
find $PREFIX/share/zeek/site/cybergon-scripts/ -type f -name '*.zeek' ! -name "*__load__*" -exec echo "@load $(basename {})" >> $PREFIX/share/zeek/site/cybergon-scripts/__load__.zeek \;
cat $PREFIX/share/zeek/site/cybergon-scripts/__load__.zeek

echo "Creating directory for file extraction..."
mkdir $PREFIX/extracted/
sed -i 's#""#"/usr/local/zeek/extracted/"#g' $PREFIX/share/zeek/site/file-extraction/config.zeek
echo -e "\n@load ./plugins/extract-archive" >> $PREFIX/share/zeek/site/file-extraction/config.zeek
echo -e "\n@load ./plugins/store-files-by-sha256" >> $PREFIX/share/zeek/site/file-extraction/config.zeek

cat <<EOF > $PREFIX/share/zeek/site/file-extraction/plugins/store-files-by-sha256.zeek
@load ../__load__
@load policy/frameworks/files/hash-all-files
@load log-add-vlan-everywhere/files

event file_sniff(f: fa_file, meta: fa_metadata)
        {
        if ( meta?\$mime_type && !hook FileExtraction::extract(f, meta) )
                {
                if ( !hook FileExtraction::ignore(f, meta) )
                        return;
                Files::add_analyzer(f, Files::ANALYZER_SHA256);
                }
        }

event file_state_remove(f: fa_file)
        {

        if ( !f\$info?\$extracted || !f\$info?\$sha256 || !f\$info?\$vlan || FileExtraction::path == "" )
                return;

        local orig = f\$info\$extracted;

        local split_orig = split_string(f\$info\$extracted, /\./);
        local extension = split_orig[|split_orig|-1];

        local dest = fmt("%s%s-%s.%s", FileExtraction::path, f\$info\$sha256, f\$info\$vlan, extension);

        local cmd = fmt("mv %s %s", orig, dest);
        when ( local result = Exec::run([\$cmd=cmd]) )
                {
                }
        f\$info\$extracted = dest;

        }
EOF

zeekctl deploy

if [ $? -eq 1 ]; then
    exit -1
fi

echo "Zeek has started..."
trap 'stop' SIGINT SIGTERM SIGHUP SIGQUIT SIGABRT SIGKILL
trap - ERR
while :; do sleep 1s; done
